const std = @import("std");

pub fn build(b: *std.Build) !void {
    _ = b.addModule("ZipponData", .{
        .root_source_file = b.path("src/main.zig"),
    });
}
