const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const dep_opts = .{ .target = target, .optimize = optimize };
    _ = dep_opts;

    _ = b.addModule("ZipponData", .{
        .root_source_file = b.path("main.zig"),
    });
}
