const std = @import("std");

const MAX_STRING_LENGTH = 1024 * 64;
var string_buffer: [MAX_STRING_LENGTH]u8 = undefined;

pub const DType = enum {
    Int,
    Float,
    Str,
    Bool,
    UUID,
    Date,
    Time,
    DateTime,

    pub fn read(self: DType, reader: anytype) !Data {
        switch (self) {
            .Int => {
                var buffer: [@sizeOf(i32)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], 4); // Maybe check here if the length read is < to the expected one. I sould mean that this is the end, idk
                return Data{ .Int = std.mem.bytesToValue(i32, &buffer) };
            },
            .Float => {
                var buffer: [@sizeOf(f64)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], 8);
                return Data{ .Float = std.mem.bytesToValue(f64, &buffer) };
            },
            .Str => {
                // Read the length of the string
                var len_buffer: [4]u8 = undefined;
                _ = try reader.readAtLeast(len_buffer[0..], 4);
                const len = std.mem.bytesToValue(u32, &len_buffer);

                // Read the string
                _ = try reader.readAtLeast(string_buffer[0..len], len);
                return Data{ .Str = string_buffer[0..len] };
            },
            .Bool => {
                var buffer: [@sizeOf(bool)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], 1);
                return Data{ .Bool = std.mem.bytesToValue(bool, &buffer) };
            },
            .UUID => {
                var buffer: [@sizeOf([16]u8)]u8 = undefined;
                _ = try reader.readAtLeast(buffer[0..], 16);
                return Data{ .UUID = std.mem.bytesToValue([16]u8, &buffer) };
            },
            .Date => {
                var buffer: [4]u8 = undefined;
                _ = try reader.readAtLeast(&buffer, 4);
                return Data{ .Date = .{
                    .year = @as(u16, buffer[0]) << 8 | buffer[1],
                    .month = buffer[2],
                    .day = buffer[3],
                } };
            },
            .Time => {
                var buffer: [4]u8 = undefined;
                _ = try reader.readAtLeast(&buffer, 4);
                return Data{ .Time = .{
                    .hour = buffer[0],
                    .minute = buffer[1],
                    .second = @as(u6, @truncate(buffer[2] >> 2)),
                    .millisecond = @as(u10, (buffer[2] & 0b11)) << 8 | buffer[3],
                } };
            },

            .DateTime => {
                var buffer: [8]u8 = undefined;
                _ = try reader.readAtLeast(&buffer, 8);
                return Data{ .DateTime = .{
                    .year = @as(u16, buffer[0]) << 8 | buffer[1],
                    .month = buffer[2],
                    .day = buffer[3],
                    .hour = buffer[4],
                    .minute = buffer[5],
                    .second = @as(u6, @truncate(buffer[6] >> 2)),
                    .millisecond = @as(u10, (buffer[6] & 0b11)) << 8 | buffer[7],
                } };
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
    Date: struct { year: u16, month: u8, day: u8 },
    Time: struct { hour: u8, minute: u8, second: u6, millisecond: u10 },
    DateTime: struct { year: u16, month: u8, day: u8, hour: u8, minute: u8, second: u6, millisecond: u10 },

    /// Number of bytes that will be use in the file
    pub fn size(self: Data) usize {
        return switch (self) {
            .Int => 4,
            .Float => 8,
            .Str => 4 + self.Str.len,
            .Bool => 1,
            .UUID => 16,
            .Date => 4,
            .Time => 4,
            .DateTime => 8,
        };
    }

    /// Write the value in bytes
    pub fn write(self: Data, writer: anytype) !void {
        switch (self) {
            .Int => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Float => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Bool => |v| try writer.writeAll(std.mem.asBytes(&v)),
            .Str => |v| {
                const len = @as(u32, @intCast(v.len));
                try writer.writeAll(std.mem.asBytes(&len));
                try writer.writeAll(v);
            },
            .UUID => |v| try writer.writeAll(&v),
            .Date => |v| {
                var buffer: [4]u8 = undefined;
                buffer[0] = @truncate(v.year >> 8);
                buffer[1] = @truncate(v.year);
                buffer[2] = v.month;
                buffer[3] = v.day;
                try writer.writeAll(std.mem.asBytes(&buffer));
            },
            .Time => |v| {
                var buffer: [4]u8 = undefined;
                buffer[0] = v.hour;
                buffer[1] = v.minute;
                buffer[2] = @as(u8, v.second) << 2 | @as(u8, @truncate(v.millisecond >> 8));
                buffer[3] = @truncate(v.millisecond);
                try writer.writeAll(std.mem.asBytes(&buffer));
            },
            .DateTime => |v| {
                var buffer: [8]u8 = undefined;
                buffer[0] = @truncate(v.year >> 8);
                buffer[1] = @truncate(v.year);
                buffer[2] = v.month;
                buffer[3] = v.day;
                buffer[4] = v.hour;
                buffer[5] = v.minute;
                buffer[6] = @as(u8, v.second) << 2 | @as(u8, @truncate(v.millisecond >> 8));
                buffer[7] = @truncate(v.millisecond);
                try writer.writeAll(std.mem.asBytes(&buffer));
            },
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

    pub fn initDate(year: u16, month: u8, day: u8) Data {
        return Data{ .Date = .{ .year = year, .month = month, .day = day } };
    }

    pub fn initTime(hour: u8, minute: u8, second: u6, millisecond: u10) Data {
        return Data{ .Time = .{ .hour = hour, .minute = minute, .second = second, .millisecond = millisecond } };
    }

    pub fn initDateTime(year: u16, month: u8, day: u8, hour: u8, minute: u8, second: u6, millisecond: u10) Data {
        return Data{ .DateTime = .{ .year = year, .month = month, .day = day, .hour = hour, .minute = minute, .second = second, .millisecond = millisecond } };
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
        if (self.index >= self.file_len) return null;

        var i: usize = 0;
        while (i < self.schema.len) : (i += 1) {
            const d = self.schema[i].read(self.reader.reader()) catch return null;
            self.data[i] = d;
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
        Data.initDate(2021, 1, 1),
        Data.initTime(12, 42, 9, 812),
        Data.initDateTime(2021, 1, 1, 12, 42, 9, 812),
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
        .Date,
        .Time,
        .DateTime,
    };
    var iter = try DataIterator.init(allocator, "test", dir, schema);
    defer iter.deinit();

    if (try iter.next()) |row| {
        try std.testing.expectEqual(row[0].Int, 1);
        try std.testing.expectApproxEqAbs(row[1].Float, 3.14159, 0.00001);
        try std.testing.expectEqual(row[2].Int, -5);
        try std.testing.expectEqualStrings(row[3].Str, "Hello world");
        try std.testing.expectEqual(row[4].Bool, true);

        try std.testing.expectEqual(row[5].Date.year, 2021);
        try std.testing.expectEqual(row[5].Date.month, 1);
        try std.testing.expectEqual(row[5].Date.day, 1);

        try std.testing.expectEqual(row[6].Time.hour, 12);
        try std.testing.expectEqual(row[6].Time.minute, 42);
        try std.testing.expectEqual(row[6].Time.second, 9);
        try std.testing.expectEqual(row[6].Time.millisecond, 812);

        try std.testing.expectEqual(row[7].DateTime.year, 2021);
        try std.testing.expectEqual(row[7].DateTime.month, 1);
        try std.testing.expectEqual(row[7].DateTime.day, 1);
        try std.testing.expectEqual(row[7].DateTime.hour, 12);
        try std.testing.expectEqual(row[7].DateTime.minute, 42);
        try std.testing.expectEqual(row[7].DateTime.second, 9);
        try std.testing.expectEqual(row[7].DateTime.millisecond, 812);
    } else {
        return error.TestUnexpectedNull;
    }

    try deleteFile("test", dir);
    try std.fs.cwd().deleteDir("tmp");
}

test "Benchmark Write and Read" {
    const allocator = std.testing.allocator;

    const schema = &[_]DType{
        .Int,
        .Float,
        .Int,
        .Str,
        .Bool,
        .Date,
        .Time,
        .DateTime,
    };

    const data = &[_]Data{
        Data.initInt(1),
        Data.initFloat(3.14159),
        Data.initInt(-5),
        Data.initStr("Hello world"),
        Data.initBool(true),
        Data.initDate(2021, 1, 1),
        Data.initTime(12, 42, 9, 812),
        Data.initDateTime(2021, 1, 1, 12, 42, 9, 812),
    };

    try benchmark(allocator, schema, data);
}

fn benchmark(allocator: std.mem.Allocator, schema: []const DType, data: []const Data) !void {
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
    const allocator = std.testing.allocator;

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

    try benchmarkType(allocator, .Int, Data.initInt(random.int(i32)));
    try benchmarkType(allocator, .Float, Data.initFloat(random.float(f64)));
    try benchmarkType(allocator, .Bool, Data.initBool(random.boolean()));
    try benchmarkType(allocator, .Str, Data.initStr("Hello world"));
    try benchmarkType(allocator, .UUID, Data.initUUID(uuid));
    try benchmarkType(allocator, .Date, Data.initDate(random.int(u16), random.int(u8), random.int(u8)));
    try benchmarkType(allocator, .Time, Data.initTime(random.int(u8), random.int(u8), random.int(u6), random.int(u10)));
    try benchmarkType(allocator, .DateTime, Data.initDateTime(random.int(u16), random.int(u8), random.int(u8), random.int(u8), random.int(u8), random.int(u6), random.int(u10)));
}

fn benchmarkType(allocator: std.mem.Allocator, dtype: DType, data: Data) !void {
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
