const std = @import("std");
const json = std.json;
const fs = std.fs;

const Booru = struct {
    name: []const u8,
    base_url: []const u8,
    token: []const u8,
    buildURL: fn (self: *const Booru, allocator: std.mem.Allocator, tag: []const u8, limit: u32) BooruError![]u8,
    parsePosts: fn (allocator: std.mem.Allocator, body: []const u8) BooruError![]Post,
};

pub const BooruError = error{
    FailedURLBuild,
    ParsingFailed,
    DownloadFailed,
};

const Post = struct {
    id: []const u8, // id is actually an int in json i think
    file_url: []const u8,
    // creator: ?[]const u8,
    rating: ?[]const u8,
    tags: ?[]const u8,
};

pub fn freePosts(allocator: std.mem.Allocator, posts: []Post) void {
    for (posts) |post| {
        allocator.free(post.id);
        allocator.free(post.file_url);
        // if (post.creator) |c| allocator.free(c);
        if (post.rating) |r| allocator.free(r);
        if (post.tags) |t| allocator.free(t);
    }
    allocator.free(posts);
}

fn tryDupeField(val: ?json.Value, allocator: std.mem.Allocator) BooruError!?[]u8 {
    if (val != null and val.? == .string) {
        return allocator.dupe(u8, val.?.string) catch |err| {
            err = Booru.ParsingFailed;
            return err;
        };
    }

    return null;
}

pub const Gelbooru = Booru{
    .name = "gelbooru",
    .base_url = "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1",
    .token = "0",
    .buildURL = gelbooruBuildURL,
    .parsePosts = gelbooruParsePosts,
};

fn gelbooruBuildURL(self: *const Booru, allocator: std.mem.Allocator, tags: []const u8, limit: u32) BooruError![]u8 {
    const url = std.fmt.allocPrint(allocator, "{s}&limit={d}&tags={s}", .{ self.base_url, limit, tags }) catch |err| {
        // oom
        err = BooruError.FailedURLBuild;
        return err;
    };
    return url;
}

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
    // defer allocator.free(posts); // caller will worry about posts lifetime

    // iterate over each posts object
    for (post_array, 0..) |item, i| {

        // not object, return err (skip in future?)
        if (item != .object) return BooruError.ParsingFailed;
        const post_obj = item.object;

        // get id, file_url, creator, rating, tags
        const id_json_val = post_obj.get("id") orelse return BooruError.ParsingFailed;
        const file_url_json_val = post_obj.get("file_url") orelse return BooruError.ParsingFailed;

        // const creator_json_val = post_obj.get("creator") orelse return BooruError.ParsingFailed;
        const rating_json_val = post_obj.get("rating") orelse return BooruError.ParsingFailed;
        const tags_json_val = post_obj.get("tags") orelse return BooruError.ParsingFailed;

        // check strings (creator, rating, tags could be null)
        if (id_json_val != .string or file_url_json_val != .string) return BooruError.ParsingFailed;

        // we will dupe the value here because
        // after deinit the parsed_body they memory will go away
        const id = allocator.dupe(u8, id_json_val.string) orelse return BooruError.ParsingFailed;
        const file_url = allocator.dupe(u8, file_url_json_val.string) orelse return BooruError.ParsingFailed;
        // const creator = try tryDupeField(creator_json_val, allocator);
        const rating = try tryDupeField(rating_json_val, allocator);
        const tags = try tryDupeField(tags_json_val, allocator);

        posts[i] = Post{
            .id = id,
            .file_url = file_url,
            // .creator = creator,
            .rating = rating,
            .tags = tags,
        };
    }

    return posts;
}
