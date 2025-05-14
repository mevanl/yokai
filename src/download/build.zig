const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // define executable module
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // define our executable
    const exe = b.addExecutable(.{
        .name = "mytest",
        .root_module = exe_module,
    });

    b.installArtifact(exe);
}
