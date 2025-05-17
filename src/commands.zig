// File:    commands.zig
// Purpose: Define commands for zooru
const std = @import("std");
const cli = @import("cli.zig");

const gelbooru = @import("booru/gelbooru.zig");
const booru_client = @import("booru/client.zig");

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub const methods = struct {

    // all of our commands
    pub const commands = struct {

        // test hello world command
        pub fn hello_func(opts: []const cli.option) bool {
            std.debug.print("Hello, ", .{});

            // look for name option
            for (opts) |opt| {
                if (std.mem.eql(u8, opt.name, "name")) {
                    if (opt.value.len > 0) {
                        std.debug.print("{s}", .{opt.value});
                    } else {
                        std.debug.print("World.", .{});
                    }

                    break;
                }
            }

            std.debug.print("!\n", .{});
            return true;
        }

        // help command
        pub fn help_func(opts: []const cli.option) bool {
            _ = opts;

            std.debug.print("Usage: zooru <command> [options]\n" ++
                "Commands:\n" ++
                "   hello   Greet someone\n" ++
                "   help    Show this message\n\n" ++
                "Options for hello\n" ++
                "   -n, --name <value>  Name to greet\n", .{});

            return true;
        }

        pub fn download_func(opts: []const cli.option) bool {
            // GPA
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();

            var source: ?[]const u8 = null;
            var tags: ?[]const u8 = null;

            // get our option values
            for (opts) |opt| {
                // stdout.print("Got option: {s} = {s}\n", .{opt.name, opt.value}) catch return false;
                if (std.mem.eql(u8, opt.name, "source")) {
                    source = opt.value;
                } else if (std.mem.eql(u8, opt.name, "tags")) {
                    tags = opt.value;
                }
            }

            if (source == null or tags == null) {
                stdout.print("Missing required options.\n", .{}) catch return false;
                return false;
            }

            stdout.print("Starting download from {s} with tags: {s}\n", .{ source.?, tags.? }) catch return false;

            // do actual downloading
            if (std.mem.eql(u8, source.?, "gelbooru")) {
                const gel = gelbooru.Gelbooru.instance();

                var client = booru_client.Client.init(allocator, &gel);
                defer client.deinit();

                client.downloadPosts(client.fetchBulkPosts(tags.?) catch return false) catch |err| {
                    stderr.print("Failed downloading post (Source: {s}, tags: {s})\nError: {any}\n", .{ source.?, tags.?, err }) catch {
                        return false;
                    };
                    return false;
                };
            } else {
                stdout.print("Unsupported source: {s}\n", .{source.?}) catch {
                    return false;
                };
                return false;
            }

            return true;
        }
    };

    // for option specific logic
    pub const options = struct {
        pub fn name_func(value: []const u8) bool {
            _ = value;
            return true;
        }
    };
};
