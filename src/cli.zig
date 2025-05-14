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

    try parse(commands, options, args, debug);
}

// take in arguments allocated with start
fn parse(commands: []const command, options: []const option, args: [][:0]u8, debug: bool) CLIError!void {
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

    // get our not null command
    const cmd = detected_command.?;
    if (debug) std.debug.print("Detected command: {s}\n", .{cmd.name});

    // allocate memory on stack for remaining args
    var detected_options: [MAX_OPTIONS]option = undefined; // we already know we have <= MAX_OPTIONS
    var detected_length: usize = 0;
    var i: usize = 2; // skip the program name, detected command

    // Parse options and capture value
    while (i < args.len) {
        const arg = args[i];

        // option starts with '-'
        if (std.mem.startsWith(u8, arg, "-")) {
            // this checks if argument has 2 --, if so skip it to get name, else its just one -
            const option_name = if (std.mem.startsWith(u8, arg[1..], "-")) arg[2..] else arg[1..];
            var matched_option: ?option = null;

            // test our option name on the list of options (check if whole name is used or short hand 1 char.)
            for (options) |opt| {
                if (std.mem.eql(u8, option_name, opt.long) or (option_name == 1 and option_name[0] == opt.short)) {
                    matched_option = opt;
                    break;
                }
            }

            // if found none
            if (matched_option == null) {
                if (debug) std.debug.print("Unknown option: {s}\n", .{arg});
                return CLIError.UnknownOption;
            }

            // get our not null option
            var opt = matched_option.?;

            // what is the value given to the option
            if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) {
                opt.value = args[i + 1];
                i += 1;
            } else {
                opt.value = "";
            }

            if (detected_length >= MAX_OPTIONS) {
                return CLIError.TooManyOptions;
            }

            // store our opt
            detected_options[detected_length] = opt;
            detected_length += 1;
        } else {
            // opt doesnt start with -
            if (debug) std.debug.print("Unexpected argument: {s}\n", .{arg});
            return CLIError.UnexpectedArguement;
        }

        i += 1;
    }

    // just get the slice of options passed
    const used_options = detected_options[0..detected_length];

    // make sure for every required option, we have all of them in our used_options
    for (cmd.required) |required| {
        var found = false;

        for (used_options) |opt| {
            if (std.mem.eql(u8, required, opt.name)) {
                found = true;
                break;
            }
        }

        if (!found) {
            if (debug) std.debug.print("Missing required option: {s}\n", .{required});
            return CLIError.MissingRequiredOption;
        }
    }
}
