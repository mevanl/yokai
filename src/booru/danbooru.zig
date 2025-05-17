const std = @import("std");
const json = std.json;
const booru = @import("booru.zig");

// danbooru differences
// file_url still exist, media_assest does as well however
// file_ext is field
// id is same

pub const Danbooru = struct {
    pub const metadata = booru.BooruMetadata{
        .name = "danbooru",
        .base_url = "https://danbooru.donmai.us/posts.json?",
        .api_key = "0", // TODO: this will have to be from file
        .docs_url = "https://danbooru.donmai.us/wiki_pages/help:api",
        .supports_bulk_post = true,
        .supports_single_post = true,
    };

    pub fn buildBulkURL(
        self: *const booru.Booru,
        allocator: std.mem.Allocator,
        tags: []const u8,
        limit: u32,
    ) booru.BooruError![]u8 {
        return std.fmt.allocPrint(allocator, "{s}&limit={d}&tags={s}", .{ self.metadata.base_url, limit, tags }) catch {
            return booru.BooruError.OutOfMemory;
        };
    }
};
