const clap = @import("clap");
const std = @import("std");
const gelbooru = @import("booru/gelbooru.zig");
const safebooru = @import("booru/safebooru.zig");
const booru_client = @import("booru/client.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // First we specify what parameters our program can take.
    const params = [_]clap.Param(u8){
        .{
            .id = 'h',
            .names = .{ .short = 'h', .long = "help" },
        },
        .{
            .id = 's',
            .names = .{ .short = 's', .long = "source" },
            .takes_value = .one,
        },
        .{
            .id = 't',
            .names = .{ .short = 't', .long = "tags" },
            .takes_value = .many,
        },
    };

    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    // Skip exe argument.
    _ = iter.next();

    var diag = clap.Diagnostic{};
    var parser = clap.streaming.Clap(u8, std.process.ArgIterator){
        .params = &params,
        .iter = &iter,
        .diagnostic = &diag,
    };

    //
    var source: ?[]const u8 = null;
    var tags: ?[]const u8 = null;

    // Because we use a streaming parser, we have to consume each argument parsed individually.
    while (parser.next() catch |err| {
        // Report useful error and exit.
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    }) |arg| {
        // arg.param will point to the parameter which matched the argument.
        switch (arg.param.id) {
            'h' => {
                // print help func
                return;
            },
            's' => source = arg.value.?,
            't' => tags = arg.value.?,
            else => unreachable,
        }
    }

    // we need both source and tags (for bulk download)
    if (source == null or tags == null) {
        stdout.print("Missing required options.\n", .{}) catch return;
        return;
    }

    stdout.print("Starting download from {s} with tags: {s}\n", .{ source.?, tags.? }) catch return;

    // do actual downloading
    if (std.mem.eql(u8, source.?, "gelbooru")) {
        const gel = gelbooru.Gelbooru.instance();

        var client = booru_client.Client.init(allocator, &gel);
        defer client.deinit();

        client.downloadPosts(client.fetchBulkPosts(tags.?) catch return) catch |err| {
            stderr.print("Failed downloading post (Source: {s}, tags: {s})\nError: {any}\n", .{ source.?, tags.?, err }) catch {
                return;
            };
            return;
        };
    } else if (std.mem.eql(u8, source.?, "safebooru")) {
        const safe = safebooru.Safebooru.instance();

        var client = booru_client.Client.init(allocator, &safe);
        defer client.deinit();

        client.downloadPosts(client.fetchBulkPosts(tags.?) catch return) catch |err| {
            stderr.print("Failed downloading post (Source: {s}, tags: {s})\nError: {any}\n", .{ source.?, tags.?, err }) catch {
                return;
            };
            return;
        };
    } else {
        stdout.print("Unsupported source: {s}\n", .{source.?}) catch {
            return;
        };

        return;
    }

    return;
}
