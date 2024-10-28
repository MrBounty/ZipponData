const std = @import("std");

// TODO: Make it work for array too
// An array, like a str take a number of entity
// Maybe pack bool in that case, but later
//
// TODO: Change so date, time and datetime become just unixtime, that is exactly a i64

const MAX_STRING_LENGTH = 1024 * 64;
var string_buffer: [MAX_STRING_LENGTH]u8 = undefined;

pub const DType = enum {
    Int,
    Float,
    Str,
    Bool,
    UUID,
    Unix,

    // I dont really like that there is a sperate function but ok
    // I had to do that so I can pass a second argument
    pub fn readStr(_: DType, reader: anytype, str_index: *usize) !Data {
        // Read the length of the string
        var len_buffer: [4]u8 = undefined;
        _ = try reader.readAtLeast(len_buffer[0..], @sizeOf(u32));
        const len = @as(usize, @intCast(std.mem.bytesToValue(u32, &len_buffer)));

        if ((str_index.* + len) > string_buffer.len) return error.BufferFull;

        // Read the string
        _ = try reader.readAtLeast(string_buffer[str_index.*..(str_index.* + len)], len);
        const data = Data{ .Str = string_buffer[str_index.*..(str_index.* + len)] };

        str_index.* += len;
        return data;
    }

    pub fn read(self: DType, reader: anytype) !Data {
        switch (self) {
            .Int => {
                var buffer: [@sizeOf(i32)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], @sizeOf(i32)); // Maybe check here if the length read is < to the expected one. I sould mean that this is the end, idk
                return Data{ .Int = std.mem.bytesToValue(i32, &buffer) };
            },
            .Float => {
                var buffer: [@sizeOf(f64)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], @sizeOf(f64));
                return Data{ .Float = std.mem.bytesToValue(f64, &buffer) };
            },
            .Str => unreachable, // Need to use readStr instead
            .Bool => {
                var buffer: [@sizeOf(bool)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], @sizeOf(bool));
                return Data{ .Bool = std.mem.bytesToValue(bool, &buffer) };
            },
            .UUID => {
                var buffer: [@sizeOf([16]u8)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], @sizeOf([16]u8));
                return Data{ .UUID = std.mem.bytesToValue([16]u8, &buffer) };
            },
            .Unix => {
                var buffer: [@sizeOf(u64)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], @sizeOf(u64));
                return Data{ .Unix = std.mem.bytesToValue(u64, &buffer) };
            },
        }
    }
};

pub const Data = union(DType) {
    Int: i32,
    Float: f64,
    Str: []const u8,
    Bool: bool,
    UUID: [16]u8,
    Unix: u64,

    /// Number of bytes that will be use in the file
    pub fn size(self: Data) usize {
        return switch (self) {
            .Int => @sizeOf(i32),
            .Float => @sizeOf(f64),
            .Str => 4 + self.Str.len,
            .Bool => @sizeOf(bool),
            .UUID => @sizeOf([16]u8),
            .Unix => @sizeOf(u64),
        };
    }

    /// Write the value in bytes
    pub fn write(self: Data, writer: anytype) !void {
        switch (self) {
            .Str => |v| {
                const len = @as(u32, @intCast(v.len));
                try writer.writeAll(std.mem.asBytes(&len));
                try writer.writeAll(v);
            },
            .UUID => |v| try writer.writeAll(&v),
            .Int => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Float => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Bool => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Unix => |v| try writer.writeAll(std.mem.asBytes(&v)),
        }
    }

    pub fn initInt(value: i32) Data {
        return Data{ .Int = value };
    }

    pub fn initFloat(value: f64) Data {
        return Data{ .Float = value };
    }

    pub fn initStr(value: []const u8) Data {
        return Data{ .Str = value };
    }

    pub fn initBool(value: bool) Data {
        return Data{ .Bool = value };
    }

    pub fn initUUID(value: [16]u8) Data {
        return Data{ .UUID = value };
    }

    pub fn initUnix(value: u64) Data {
        return Data{ .Unix = value };
    }
};

pub const DataIterator = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    reader: std.io.BufferedReader(4096, std.fs.File.Reader),

    schema: []const DType,
    data: []Data,

    index: usize = 0,
    file_len: usize,
    str_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, dir: ?std.fs.Dir, schema: []const DType) !DataIterator {
        const d_ = dir orelse std.fs.cwd();
        const file = try d_.openFile(name, .{ .mode = .read_only });

        return DataIterator{
            .allocator = allocator,
            .file = file,
            .schema = schema,
            .reader = std.io.bufferedReader(file.reader()),
            .data = try allocator.alloc(Data, schema.len),
            .file_len = try file.getEndPos(),
        };
    }

    pub fn deinit(self: *DataIterator) void {
        self.allocator.free(self.data);
        self.file.close();
    }

    pub fn next(self: *DataIterator) !?[]Data {
        self.str_index = 0;
        if (self.index >= self.file_len) return null;

        var i: usize = 0;
        while (i < self.schema.len) : (i += 1) {
            self.data[i] = switch (self.schema[i]) {
                .Str => try self.schema[i].readStr(self.reader.reader(), &self.str_index),
                else => try self.schema[i].read(self.reader.reader()),
            };
            self.index += self.data[i].size();
        }

        return self.data;
    }
};

pub const DataWriter = struct {
    file: std.fs.File,
    writer: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(name: []const u8, dir: ?std.fs.Dir) !DataWriter {
        const d_ = dir orelse std.fs.cwd();
        const file = try d_.openFile(name, .{ .mode = .write_only });
        try file.seekFromEnd(0);

        return DataWriter{
            .file = file,
            .writer = std.io.bufferedWriter(file.writer()),
        };
    }

    pub fn deinit(self: *DataWriter) void {
        self.file.close();
    }

    pub fn write(self: *DataWriter, data: []const Data) !void {
        for (data) |d| try d.write(self.writer.writer());
    }

    pub fn flush(self: *DataWriter) !void {
        try self.writer.flush();
    }
};

pub fn createFile(name: []const u8, dir: ?std.fs.Dir) !void {
    const d = dir orelse std.fs.cwd();
    const file = try d.createFile(name, .{});
    defer file.close();
}

pub fn deleteFile(name: []const u8, dir: ?std.fs.Dir) !void {
    const d = dir orelse std.fs.cwd();
    try d.deleteFile(name);
}

pub fn statFile(name: []const u8, dir: ?std.fs.Dir) !std.fs.File.Stat {
    const d = dir orelse std.fs.cwd();
    return d.statFile(name);
}

test "Write and Read" {
    const allocator = std.testing.allocator;

    try std.fs.cwd().makeDir("tmp");
    const dir = try std.fs.cwd().openDir("tmp", .{});

    const data = [_]Data{
        Data.initInt(1),
        Data.initFloat(3.14159),
        Data.initInt(-5),
        Data.initStr("Hello world"),
        Data.initBool(true),
        Data.initUnix(12476),
        Data.initStr("Another string =)"),
    };

    try createFile("test", dir);

    var dwriter = try DataWriter.init("test", dir);
    defer dwriter.deinit();
    try dwriter.write(&data);
    try dwriter.flush();

    const schema = &[_]DType{
        .Int,
        .Float,
        .Int,
        .Str,
        .Bool,
        .Unix,
        .Str,
    };
    var iter = try DataIterator.init(allocator, "test", dir, schema);
    defer iter.deinit();

    if (try iter.next()) |row| {
        try std.testing.expectEqual(row[0].Int, 1);
        try std.testing.expectApproxEqAbs(row[1].Float, 3.14159, 0.00001);
        try std.testing.expectEqual(row[2].Int, -5);
        try std.testing.expectEqualStrings(row[3].Str, "Hello world");
        try std.testing.expectEqual(row[4].Bool, true);
        try std.testing.expectEqual(row[5].Unix, 12476);
        try std.testing.expectEqualStrings(row[6].Str, "Another string =)");
    } else {
        return error.TestUnexpectedNull;
    }

    try deleteFile("test", dir);
    try std.fs.cwd().deleteDir("tmp");
}

test "Benchmark Write and Read" {
    const schema = &[_]DType{
        .Int,
        .Float,
        .Int,
        .Str,
        .Bool,
        .Unix,
    };

    const data = &[_]Data{
        Data.initInt(1),
        Data.initFloat(3.14159),
        Data.initInt(-5),
        Data.initStr("Hello world"),
        Data.initBool(true),
        Data.initUnix(2021),
    };

    try benchmark(schema, data);
}

fn benchmark(schema: []const DType, data: []const Data) !void {
    const allocator = std.testing.allocator;
    const sizes = [_]usize{ 1, 10, 100, 1_000, 10_000, 100_000, 1_000_000 };

    try std.fs.cwd().makeDir("benchmark_tmp");
    const dir = try std.fs.cwd().openDir("benchmark_tmp", .{});
    defer std.fs.cwd().deleteDir("benchmark_tmp") catch {};

    for (sizes) |size| {
        std.debug.print("\nBenchmarking with {d} rows:\n", .{size});

        // Benchmark write
        const write_start = std.time.nanoTimestamp();
        try createFile("benchmark", dir);

        var dwriter = try DataWriter.init("benchmark", dir);
        defer dwriter.deinit();
        for (0..size) |_| try dwriter.write(data);
        try dwriter.flush();
        const write_end = std.time.nanoTimestamp();
        const write_duration = @as(f64, @floatFromInt(write_end - write_start)) / 1e6;

        std.debug.print("Write time: {d:.6} ms\n", .{write_duration});
        std.debug.print("Average write time: {d:.2} μs\n", .{write_duration / @as(f64, @floatFromInt(size)) * 1000});

        // Benchmark read
        const read_start = std.time.nanoTimestamp();
        var iter = try DataIterator.init(allocator, "benchmark", dir, schema);
        defer iter.deinit();

        var count: usize = 0;
        while (try iter.next()) |_| {
            count += 1;
        }
        const read_end = std.time.nanoTimestamp();
        const read_duration = @as(f64, @floatFromInt(read_end - read_start)) / 1e6;

        std.debug.print("Read time: {d:.6} ms\n", .{read_duration});
        std.debug.print("Average read time: {d:.2} μs\n", .{read_duration / @as(f64, @floatFromInt(size)) * 1000});
        try std.testing.expectEqual(count, size);

        std.debug.print("{any}", .{statFile("benchmark", dir)});

        try deleteFile("benchmark", dir);
        std.debug.print("\n", .{});
    }
}

test "Benchmark Type" {
    const random = std.crypto.random;
    const uuid = [16]u8{
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
        random.int(u8),
    };

    try benchmarkType(.Int, Data.initInt(random.int(i32)));
    try benchmarkType(.Float, Data.initFloat(random.float(f64)));
    try benchmarkType(.Bool, Data.initBool(random.boolean()));
    try benchmarkType(.Str, Data.initStr("Hello world"));
    try benchmarkType(.UUID, Data.initUUID(uuid));
    try benchmarkType(.Unix, Data.initUnix(random.int(u64)));
}

fn benchmarkType(dtype: DType, data: Data) !void {
    const allocator = std.testing.allocator;

    const size = 1_000_000;

    try std.fs.cwd().makeDir("benchmark_type_tmp");
    const dir = try std.fs.cwd().openDir("benchmark_type_tmp", .{});
    defer std.fs.cwd().deleteDir("benchmark_type_tmp") catch {};

    std.debug.print("\nBenchmarking with {any} rows:\n", .{dtype});

    // Benchmark write
    const write_start = std.time.nanoTimestamp();
    try createFile("benchmark", dir);

    const datas = &[_]Data{data};

    var dwriter = try DataWriter.init("benchmark", dir);
    defer dwriter.deinit();
    for (0..size) |_| try dwriter.write(datas);
    try dwriter.flush();
    const write_end = std.time.nanoTimestamp();
    const write_duration = @as(f64, @floatFromInt(write_end - write_start)) / 1e6;

    std.debug.print("Write time: {d:.6} ms\n", .{write_duration});

    const schema = &[_]DType{dtype};

    // Benchmark read
    const read_start = std.time.nanoTimestamp();
    var iter = try DataIterator.init(allocator, "benchmark", dir, schema);
    defer iter.deinit();

    var count: usize = 0;
    while (try iter.next()) |_| {
        count += 1;
    }
    const read_end = std.time.nanoTimestamp();
    const read_duration = @as(f64, @floatFromInt(read_end - read_start)) / 1e6;

    std.debug.print("Read time: {d:.6} ms\n", .{read_duration});
    try std.testing.expectEqual(count, size);

    std.debug.print("{any}", .{statFile("benchmark", dir)});

    try deleteFile("benchmark", dir);
    std.debug.print("\n", .{});
}
