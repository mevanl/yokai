const std = @import("std");
const booru = @import("booru.zig");
const http = std.http;
const fs = std.fs;

// Client handles the http component
// Once getting the response body.
const Client = struct {
    allocator: std.mem.Allocator,
    http_client: http.Client,
    booru_handler: *const booru.Booru,

    pub fn init(allocator: std.mem.Allocator, booru_handler: *booru.Booru) Client {
        return Client{
            .allocator = allocator,
            .http_client = http.Client{ .allocator = allocator },
            .booru_handler = booru_handler,
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
    }

    pub fn fetchPosts(self: *Client, tags: []const u8, limit: u32) ![]booru.Post {
        const url = try self.booru_handler.buildURL(self.booru_handler, self.allocator, tags, limit);
        defer self.allocator.free(url);

        var req = try self.http_client.open(.GET, try std.Uri.parse(url), .{});
        defer req.deinit();

        try req.send();
        try req.finish();
        try req.wait();

        const body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024 * 4);
        defer self.allocator.free(body);

        return try self.booru_handler.parsePosts(self.allocator, body);
    }

    pub fn downloadPosts(self: *Client, posts: []booru.Post) booru.BooruError!void {

        // post is no longer needed after this
        defer booru.freePosts(self.allocator, posts);

        for (posts) |post| {

            // url to post file
            const url = std.Uri.parse(post.file_url) catch return booru.BooruError.DownloadFailed;

            // open and send request
            const buffer: [1024 * 4]u8 = undefined;
            var req = self.http_client.open(.GET, url, .{ .server_header_buffer = buffer }) catch return booru.BooruError.DownloadFailed;
            defer req.deinit();

            try req.send();
            try req.finish();
            try req.wait();

            // build file name
            const file_extension = getFileExtension(post.file_url) catch |err| return err;
            const file_name = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ post.id, file_extension }) catch return booru.BooruError.DownloadFailed;
            defer self.allocator.free(file_name);

            // create output file
            var file = std.fs.cwd().createFile(file_name, .{ .exclusive = true }) catch |err| {
                std.debug.print("Error creating file {s}, Error: {any}", .{ file_name, err });
                continue;
            };
            defer file.close();

            // stream response to disk
            const reader = req.reader();
            const writer = file.writer();

            var stream_buffer: [1024 * 1024]u8 = undefined;
            while (true) {
                const bytes_read = try reader.read(&stream_buffer);
                if (bytes_read == 0) break; // finished reading
                try writer.writeAll(stream_buffer[0..bytes_read]);
            }
        }
    }
};

fn getFileExtension(url: []const u8) booru.BooruError![]const u8 {
    const last_dot = std.mem.lastIndexOfScalar(u8, url, '.');
    if (last_dot) |i| {
        return url[i..];
    } else {
        return booru.BooruError.DownloadFailed;
    }
}
