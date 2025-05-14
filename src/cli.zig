// File: cli.zig
// Purpose: Define core data structure
//          to represent commands and options
const std = @import("std");
const builtin = @import("builtin");

pub const MAX_COMMANDS: u8 = 10;
pub const MAX_OPTIONS: u8 = 20;

// Structure of a command to execute
pub const command = struct {
    name: []const u8, // Name of command
    function: fn_type, // Function to execute
    required: []const []const u8 = &.{}, // Required args
    optional: []const []const u8 = &.{}, // optional args
    const fn_type = *const fn ([]const option) bool;
};

// Structure for option
pub const option = struct {
    name: []const u8,
    function: ?fn_type = null,
    short: u8,
    long: []const u8,
    value: []const u8 = "",
    const fn_type = *const fn ([]const u8) bool;
};

// CLI Errors
pub const CLIError = error{
    NoArgsProvided,
    UnknownCommand,
    UnknownOption,
    MissingRequiredOption,
    UnexpectedArguement,
    CommandExecutionFailed,
    TooManyCommands,
    TooManyOptions,
    FailedAllocation,
};

// Starts yokai CLI handler
pub fn start(commands: []const command, options: []const option, debug: bool) CLIError!void {

    // handle simple argument based errors
    if (commands.len > MAX_COMMANDS) return CLIError.TooManyCommands;
    if (options.len > MAX_OPTIONS) return CLIError.TooManyOptions;

    // GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    // get our cmdline args
    const args = std.process.argsAlloc(gpa_allocator) catch {
        return CLIError.FailedAllocation;
    };
    defer std.process.argsFree(gpa_allocator, args);

    try parse_and_start(commands, options, args, debug);
}

// take in arguments allocated with start
fn parse_and_start(commands: []const command, options: []const option, args: [][:0]u8, debug: bool) CLIError!void {
    // only arg is program name
    if (args.len < 2) {
        if (debug) std.debug.print("Please enter a command!\n", .{});
        return CLIError.NoArgsProvided;
    }

    // extract command name (first arg is program name)
    const command_name = args[1];
    var detected_command: ?command = null;

    // see if the command is in the list of valid commands
    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, command_name)) {
            // match
            detected_command = cmd;
            break;
        }
    }

    // not real command
    if (detected_command == null) {
        if (debug) std.debug.print("Unknow command {s}\n", .{command_name});
        return CLIError.UnknownCommand;
    }

    // get our non-nullable command
    const cmd = detected_command.?;
    if (debug) std.debug.print("Detected command: {s}\n", .{cmd.name});
}
