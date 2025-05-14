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
pub const Error = error{
    NoArgsProvided,
    UnknownCommand,
    UnknownOption,
    MissingRequiredOption,
    UnexpectedArguement,
    CommandExecutionFailed,
    TooManyCommands,
    TooManyOptions,
};
