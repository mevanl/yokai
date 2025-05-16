const std = @import("std");
const http = std.http;
const json = std.json;
const fs = std.fs;
const print = std.debug.print;

const Post = struct {
    id: []const u8,
    file_url: []const u8,
    //creator: ?[]const u8,
    rating: ?[]const u8,
    tags: ?[]const u8,
};

pub fn main() !void {
    // gpa
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    // test post
    const post = Post{
        .id = "11945670",
        .file_url = "https://img4.gelbooru.com/images/bf/86/bf8676bef5fa4f703776531aa94b78e0.jpg",
        //.creator = "",
        .rating = "general",
        .tags = "animal_focus blue_eyes blue_fur blue_sclera bob_cut brown_eyes brown_fur brown_sclera closed_mouth colored_sclera colored_skin forked_tail fu_6uk gardevoir gen_3_pokemon gen_4_pokemon glaceon green_fur green_hair hair_over_one_eye highres leafeon multicolored_skin nintendo no_humans open_mouth pawpads pokemon pokemon_(creature) pokemon_focus simple_background smile tail white_skin yellow_fur",
    };

    const url = try std.Uri.parse(post.file_url);

    const buffer = try allocator.alloc(u8, 1024 * 1024 * 4);
    defer allocator.free(buffer);

    var req = try client.open(.GET, url, .{ .server_header_buffer = buffer });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const res = try req.reader().readAllAlloc(allocator, 1024 * 1024 * 4);
    defer allocator.free(res);

    print("{any}", .{res});

    const file_extension = getFileExtension(post.file_url) catch |err| {
        return err;
    };
    const file_name = std.fmt.allocPrint(allocator, "{s}{s}", .{ post.id, file_extension }) catch |err| {
        return err;
    };
    defer allocator.free(file_name);

    // write to file
    var file = try std.fs.cwd().createFile(file_name, .{});
    defer file.close();

    try file.writeAll(res);
}

// real one would be returning an error not null
fn getFileExtension(url: []const u8) ![]const u8 {
    const last_dot = std.mem.lastIndexOfScalar(u8, url, '.');
    if (last_dot) |i| {
        return url[i..];
    } else {
        return error.Failure;
    }
}
