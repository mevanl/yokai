const std = @import("std");
const json = std.json;

const Booru = struct {
    name: []const u8,
    base_url: []const u8,
    token: []const u8,
    buildURL: fn (self: *const Booru, allocator: std.mem.Allocator, tag: []const u8, limit: u32) BooruError![]u8,
    parsePosts: fn (allocator: std.mem.Allocator, body: []const u8) BooruError![]Post,
    downloadPosts: fn (allocator: std.mem.Allocator, posts: []Post) BooruError!void,
};

const Post = struct {
    id: []const u8,
    file_url: []const u8,
    creator: ?[]const u8,
    rating: ?[]const u8,
    tags: ?[]const u8,
};

pub const BooruError = error{
    FailedURLBuild,
    ParsingFailed,
    DownloadFailed,
};

fn defaultBuildURL(
    self: *const Booru,
    allocator: std.mem.Allocator,
    tags: []const u8,
    limit: u32,
) BooruError![]u8 {
    const url = std.fmt.allocPrint(allocator, "{s}&limit={d}&tags={s}", .{ self.base_url, limit, tags }) catch |err| {
        // oom
        err = BooruError.FailedURLBuild;
        return err;
    };
    return url;
}

pub const Gelbooru = Booru{
    .name = "gelbooru",
    .base_url = "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1",
    .token = "0",
    .buildURL = defaultBuildURL,
    .parsePosts = gelbooruParsePosts,
};

fn gelbooruParsePosts(allocator: std.mem.Allocator, body: []const u8) BooruError![]Post {

    // body is a json string, parse into json
    var parsed_body = json.parseFromSlice(json.Value, allocator, body, .{}) catch |err| {
        // errors are all unrecoverable from.
        err = BooruError.ParsingFailed;
        return err;
    };
    defer parsed_body.deinit();

    // get just the posts from the body, post should be an array of post for a given query
    const post_json = parsed_body.value.object.get("post") orelse return BooruError.ParsingFailed;
    if (post_json != .array) return BooruError.ParsingFailed;

    // make post_json into array we can iterate over
    const post_array = post_json.array.items;

    // space for our posts
    var posts = allocator.alloc(Post, post_array.len) catch |err| {
        // oom
        err = BooruError.ParsingFailed;
        return err;
    };
    defer allocator.free(posts);

    // iterate over each posts object
    for (post_array, 0..) |item, i| {

        // not object, return err (skip in future?)
        if (item != .object) return BooruError.ParsingFailed;
        const post_obj = item.object;

        // get id, file_url, creator, rating, tags
        const id_json_val = post_obj.get("id") orelse return BooruError.ParsingFailed;
        const file_url_json_val = post_obj.get("file_url") orelse return BooruError.ParsingFailed;

        const creator_json_val = post_obj.get("creator") orelse return BooruError.ParsingFailed;
        const rating_json_val = post_obj.get("rating") orelse return BooruError.ParsingFailed;
        const tags_json_val = post_obj.get("tags") orelse return BooruError.ParsingFailed;

        // check strings (creator, rating, tags could be null)
        if (id_json_val != .string or file_url_json_val != .string) return BooruError.ParsingFailed;

        posts[i] = Post{
            .id = id_json_val.string,
            .file_url = file_url_json_val.string,
            .creator = if (creator_json_val != null and creator_json_val.? == .string) creator_json_val.?.string else null,
            .rating = if (rating_json_val != null and rating_json_val.? == .string) rating_json_val.?.string orelse null,
            .tags = if (tags_json_val != null and tags_json_val.? == .string) tags_json_val.?.string orelse null,
        };
    }

    return posts;
}
