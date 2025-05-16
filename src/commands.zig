// File: commands.zig
// Purpose: Define commands for zooru
const std = @import("std");
const cli = @import("cli.zig");

const booru = @import("app/booru.zig");
const bclient = @import("app/booru_client.zig");

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
    };

    // for option specific logic
    pub const options = struct {
        pub fn name_func(value: []const u8) bool {
            _ = value;
            return true;
        }
    };
};
