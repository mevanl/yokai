// File:    booru.zig
// Purpose: Defines Booru interface-struct, Post struct
//          Booru errors, and helper functions for them.
const std = @import("std");

pub const Booru = struct {
    name: []const u8,
    base_url: []const u8,
    metadata: BooruMetadata,

    //buildSingleURL
    //parseSinglePost
    buildBulkURL: ?fn (self: *const Booru, allocator: std.mem.Allocator, tags: []const u8, limit: u32) BooruError![]u8,
    parseBulkPost: ?fn (allocator: std.mem.Allocator, body: []const u8) BooruError![]Post,
};

pub const BooruMetadata = struct {
    api_key: ?[]const u8,
    docs_url: ?[]const u8,

    supports_single_post: bool,
    supports_bulk_post: bool,
};

pub const Post = struct {
    id: ?[]const u8, // u32 maybe if all boorus are uint
    file_url: []const u8, // direct link to media itself,
};

pub const BooruError = error{
    InvalidInput,
    FailedURLBuild,
    ParsingFailed,
    OutOfMemory,

    RequestFailed,
    ResponseReadFailed,
    DownloadFailed,
    UnsupportedOperation,
};

pub fn freePosts(allocator: std.mem.Allocator, posts: []Post) void {
    for (posts) |post| {
        allocator.free(post.id);
        allocator.free(post.file_url);
    }

    allocator.free(posts);
}

pub fn tryDupeJsonValue(val: ?std.json.Value, allocator: std.mem.Allocator) BooruError!?[]u8 {
    if (val != null and val.? == .string) {
        return allocator.dupe(u8, val.?.string) catch BooruError.OutOfMemory;
    }
    return null;
}
