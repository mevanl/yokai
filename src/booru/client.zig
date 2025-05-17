const std = @import("std");
const http = std.http;
const booru = @import("booru.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

// context to pass to worker threads
const WorkerContext = struct {
    allocator: std.mem.Allocator,
    handler: *const booru.Booru,
    posts: []booru.Post,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    handler: *const booru.Booru,

    pub fn init(allocator: std.mem.Allocator, handler: *const booru.Booru) Client {
        return .{
            .allocator = allocator,
            .handler = handler,
        };
    }

    // pub fn fetchSinglePost(self: *Client, post_id: []const u8) booru.BooruError!booru.Post {}

    pub fn fetchBulkPosts(self: *Client, tags: []const u8) booru.BooruError![]booru.Post {
        if (!self.handler.metadata.supports_bulk_post) {
            return booru.BooruError.UnsupportedOperation;
        }

        // hard coded limit for now
        const url = try self.handler.buildBulkURL(self.handler, self.allocator, tags, 5);
        defer self.allocator.free(url);

        const body = try self.getBulkBody(url);
        defer self.allocator.free(body);

        return try self.handler.parseBulkPost(self.allocator, body);
    }

    pub fn downloadPost(self: *Client, post: booru.Post) booru.BooruError!void {

        // http client for this download
        var download_client = http.Client{ .allocator = self.allocator };
        defer download_client.deinit();

        const url = std.Uri.parse(post.file_url) catch return booru.BooruError.DownloadFailed;

        // make and send our request
        var header_buffer: [1024 * 4]u8 = undefined;
        var req = download_client.open(.GET, url, .{ .server_header_buffer = &header_buffer }) catch return booru.BooruError.RequestFailed;
        defer req.deinit();

        req.send() catch return booru.BooruError.RequestFailed;
        req.finish() catch return booru.BooruError.RequestFailed;
        req.wait() catch return booru.BooruError.RequestFailed;

        // create file for res data
        const file_extension = try getFileExtension(post.file_url);
        const file_name = std.fmt.allocPrint(self.allocator, "{d}{s}", .{ post.id, file_extension }) catch return booru.BooruError.OutOfMemory;
        defer self.allocator.free(file_name);

        var file = std.fs.cwd().createFile(file_name, .{ .exclusive = true }) catch |err| {
            stderr.print("Error creating file {s}. Error: {any}\n", .{ file_name, err }) catch return booru.BooruError.DownloadFailed;
            return booru.BooruError.DownloadFailed;
        };
        defer file.close();

        // read res, write to file
        const reader = req.reader();
        const writer = file.writer();

        var stream_buffer: [1024 * 1024]u8 = undefined;
        while (true) {
            const bytes_read = reader.read(&stream_buffer) catch return booru.BooruError.DownloadFailed;
            if (bytes_read == 0) break;
            writer.writeAll(stream_buffer[0..bytes_read]) catch return booru.BooruError.DownloadFailed;
        }
    }

    fn downloadPostsSerial(self: *Client, posts: []booru.Post) booru.BooruError!void {
        for (posts) |post| {
            self.downloadPost(post) catch |err| {
                stderr.print("Error downloading post {d}: {any}\n", .{ post.id, err }) catch {};
            };
            // Add a small delay between requests to avoid overwhelming the server
            std.time.sleep(500 * std.time.ns_per_ms);
        }
    }

    pub fn downloadPosts(self: *Client, posts: []booru.Post) booru.BooruError!void {
        if (posts.len == 0) return booru.BooruError.NoPostFound;

        const num_threads = min(std.Thread.getCpuCount() catch 1, posts.len);

        // if cant parallelize
        if (num_threads == 1) {
            try self.downloadPostsSerial(posts);
            return;
        }

        // otherwise parallelize downloading

        const chunk_size = posts.len / num_threads;
        const remainder_size = posts.len % num_threads;

        // make threads
        const threads = self.allocator.alloc(std.Thread, num_threads) catch return booru.BooruError.OutOfMemory;
        defer self.allocator.free(threads);

        // this makes copies of the posts for each thread to work on
        var contexts = self.allocator.alloc(WorkerContext, num_threads) catch return booru.BooruError.OutOfMemory;
        defer self.allocator.free(contexts);

        // each thread do their work
        for (threads, 0..) |*thread, i| {

            // where i start my work
            // where i end (if last thread, tack on the remaining work)
            const start = i * chunk_size;
            const end = start + chunk_size + if (i == num_threads - 1) remainder_size else 0;

            contexts[i] = .{
                .allocator = self.allocator,
                .handler = self.handler,
                .posts = posts[start..end],
            };

            thread.* = std.Thread.spawn(.{}, downloadWorker, .{&contexts[i]}) catch return booru.BooruError.ThreadError;
        }

        // waiting for all threads done
        for (threads) |t| t.join();

        // safe to free the posts array
        booru.freePosts(self.allocator, posts);
    }

    fn getBulkBody(self: *Client, url: []const u8) booru.BooruError![]u8 {
        const parsed = std.Uri.parse(url) catch return booru.BooruError.FailedURLBuild;

        // Create a dedicated HTTP client for this request
        var http_client = http.Client{ .allocator = self.allocator };
        defer http_client.deinit();

        var header_buffer: [1024 * 4]u8 = undefined;
        var req = http_client.open(.GET, parsed, .{ .server_header_buffer = &header_buffer }) catch return booru.BooruError.RequestFailed;
        defer req.deinit();

        req.send() catch return booru.BooruError.RequestFailed;
        req.finish() catch return booru.BooruError.RequestFailed;
        req.wait() catch return booru.BooruError.RequestFailed;

        const max_response_size = 1024 * 1024 * 4; // 4 MB upper bound for safety
        return req.reader().readAllAlloc(self.allocator, max_response_size) catch return booru.BooruError.ResponseReadFailed;
    }

    // get file extensions (.png, .jpg, etc.)
    fn getFileExtension(url: []const u8) booru.BooruError![]const u8 {
        const last_dot = std.mem.lastIndexOfScalar(u8, url, '.');
        if (last_dot) |i| {
            return url[i..];
        } else {
            return booru.BooruError.ParsingFailed;
        }
    }
};

// worker for multithreaded bulk download
fn downloadWorker(context: *WorkerContext) void {
    // Create a new client for this thread
    var client = Client.init(context.allocator, context.handler);

    // download our portion of the posts
    for (context.posts) |post| {
        client.downloadPost(post) catch |err| {
            stderr.print("Error downloading post {d}: {any}\n", .{ post.id, err }) catch {};
        };

        // Rate limit (100ms between downloads within a thread)
        std.time.sleep(100 * std.time.ns_per_ms);
    }
}

fn min(a: usize, b: usize) usize {
    return if (a < b) a else b;
}
