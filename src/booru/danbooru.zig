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

    pub fn parseBulkPost(
        allocator: std.mem.Allocator,
        body: []const u8,
    ) booru.BooruError![]booru.Post {

        // parse body string into Json values
        var parsed_body = json.parseFromSlice(json.Value, allocator, body, .{}) catch {
            return booru.BooruError.ParsingFailed;
        };
        defer parsed_body.deinit();

        const posts_array = parsed_body.value.array.items;

        if (posts_array.len == 0) {
            return booru.BooruError.NoPostFound;
        }

        // alloc space for all the posts (struct array)
        var posts = allocator.alloc(booru.Post, posts_array.len) catch {
            return booru.BooruError.OutOfMemory;
        };

        // create post and put into posts
        for (posts_array, 0..) |item, i| {

            // if item isnt an object skip
            if (item != .object) return booru.BooruError.ParsingFailed;
            const post_obj = item.object;

            // get id and file url
            const id_json = post_obj.get("id") orelse return booru.BooruError.ParsingFailed;
            const file_url_json = post_obj.get("file_url") orelse return booru.BooruError.ParsingFailed;

            // check valid type
            if (id_json != .integer or file_url_json != .string) return booru.BooruError.ParsingFailed;

            // duplicate them
            const id = id_json.integer;
            const file_url = allocator.dupe(u8, file_url_json.string) catch return booru.BooruError.OutOfMemory;

            posts[i] = booru.Post{ .id = id, .file_url = file_url };
        }

        return posts;
    }

    pub fn instance() booru.Booru {
        return booru.Booru{
            .metadata = metadata,
            .buildBulkURL = &buildBulkURL,
            .parseBulkPost = &parseBulkPost,
        };
    }
};

fn tryDupeField(val: ?json.Value, allocator: std.mem.Allocator) booru.BooruError!?[]u8 {
    if (val != null and val.? == .string) {
        return allocator.dupe(u8, val.?.string) catch {
            return booru.BooruError.OutOfMemory;
        };
    }

    return null;
}
