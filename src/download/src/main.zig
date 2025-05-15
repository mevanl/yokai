const std = @import("std");
const http = std.http;
const json = std.json;

const gelbooru_api = "https://gelbooru.com/index.php?page=dapi&s=post&q=index&json=1";

pub fn main() !void {

    // create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // create http client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    const buffer = try allocator.alloc(u8, 1024 * 1024 * 4);
    defer allocator.free(buffer);

    // build the request
    const limit = 1;
    const tag = "catgirl";

    const url = try std.fmt.allocPrint(allocator, "{s}&limit={d}&tags={s}", .{ gelbooru_api, limit, tag });
    defer allocator.free(url);

    const uri = try std.Uri.parse(url);

    var req = try client.open(.GET, uri, .{ .server_header_buffer = buffer });
    defer req.deinit();

    // start http request
    try req.send();
    try req.finish();
    try req.wait();

    //try std.testing.expectEqual(req.response.status, .ok);

    // read the body (is a string)
    const body = try req.reader().readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(body);

    // Parse to JSON
    var parsed = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsed.deinit();

    // get all posts
    const posts_array_val = parsed.value.object.get("post") orelse return error.MissingPosts;
    if (posts_array_val != .array) {
        return error.InvalidFormat;
    }

    const posts = posts_array_val.array.items;

    // make sure atleast one post
    if (posts.len == 0) {
        return error.NoPosts;
    }

    const first_post_val = posts[0];
    if (first_post_val != .object) {
        return error.InvalidFormat;
    }

    // only first post
    const post = first_post_val.object;

    // get source using same method
    const source_val = post.get("source") orelse return error.MissingRequiredKey;
    if (source_val != .string) {
        return error.InvalidFormat;
    }

    const source = source_val.string;

    std.debug.print("{s}\n", .{source});
}
