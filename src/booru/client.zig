const std = @import("std");
const http = std.http;
const booru = @import("booru.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub const Client = struct {
    allocator: std.mem.Allocator,
    http_client: http.Client,
    handler: *const booru.Booru,

    pub fn init(allocator: std.mem.Allocator, handler: *const booru.Booru) Client {
        return .{
            .allocator = allocator,
            .http_client = .{ .allocator = allocator },
            .handler = handler,
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
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
        const url = std.Uri.parse(post.file_url) catch return booru.BooruError.DownloadFailed;

        // make and send our request
        var header_buffer: [1024 * 4]u8 = undefined;
        var req = self.http_client.open(.GET, url, .{ .server_header_buffer = &header_buffer }) catch return booru.BooruError.RequestFailed;
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

    pub fn downloadPosts(self: *Client, posts: []booru.Post) booru.BooruError!void {
        defer booru.freePosts(self.allocator, posts);

        for (posts) |post| {
            self.downloadPost(post) catch {
                stderr.print("Error download post: {d}\n", .{post.id}) catch continue;
            };
        }
    }

    fn getBulkBody(self: *Client, url: []const u8) booru.BooruError![]u8 {
        const parsed = std.Uri.parse(url) catch return booru.BooruError.FailedURLBuild;

        var header_buffer: [1024 * 4]u8 = undefined;
        var req = self.http_client.open(.GET, parsed, .{ .server_header_buffer = &header_buffer }) catch return booru.BooruError.RequestFailed;
        defer req.deinit();

        req.send() catch return booru.BooruError.RequestFailed;
        req.finish() catch return booru.BooruError.RequestFailed;
        req.wait() catch return booru.BooruError.RequestFailed;

        const max_response_size = 1024 * 1024 * 4; // 4 MB upper bound for safety
        return req.reader().readAllAlloc(self.allocator, max_response_size) catch return booru.BooruError.ResponseReadFailed;
    }

    fn getFileExtension(url: []const u8) booru.BooruError![]const u8 {
        const last_dot = std.mem.lastIndexOfScalar(u8, url, '.');
        if (last_dot) |i| {
            return url[i..];
        } else {
            return booru.BooruError.ParsingFailed;
        }
    }
};
