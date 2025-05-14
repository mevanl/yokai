const std = @import("std");
const http = std.http;
const json = std.json;
const writer = std.io.getStdOut().writer();

const Result = struct {

};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator.init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // client
    var client = std.http.Client{ .allocator = allocator };

    const response = try get("")
}

fn get(
    url: []const u8,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    try writer.print("\nURL: {s} GET\n", .{url}); 

    var 
}
