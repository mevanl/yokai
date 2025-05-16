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

    pub fn init(allocator: std.mem.Allocator, booru_handler: *const booru.Booru) Client {
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

    pub fn downloadPosts(self: *Client, posts: []booru.Post) !void {

        // post is no longer needed after this
        defer booru.freePosts(self.allocator, posts);
    }
};
