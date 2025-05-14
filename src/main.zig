const std = @import("std");
const cli = @import("cli.zig");
const cmd = @import("commands.zig");

pub fn main() !void {

    // define our programs commands
    const commands = [_]cli.command{ cli.command{
        .name = "hello",
        .function = &cmd.methods.commands.hello_func,
        .optional = &.{"name"},
    }, cli.command{
        .name = "help",
        .function = &cmd.methods.commands.help_func,
    } };

    // define our programs options
    const options = [_]cli.option{
        cli.option{
            .name = "name",
            .short = 'n',
            .long = "name",
            .function = &cmd.methods.options.name_func,
        },
    };

    // start yokai
    try cli.start(&commands, &options, true);
}
