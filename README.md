# ZipponData

ZipponData is a library developped in the context of [ZipponDB](https://github.com/MrBounty/ZipponDB/tree/v0.1.3).

The library intent to create a simple way to store and parse data from a file in the most efficient and fast way possible. 

There is 8 data type available in ZipponData:

| Type | Zig type | Bytes in file |
| --- | --- | --- |
| int | i32 | 4 |
| float | f64 | 8 |
| bool | bool | 1 |
| str | []u8 | 4 + len |
| uuid | [16]u8 | 16 |
| date | custom | 4 |
| time | custom | 4 |
| datetime | custom | 8 |

## Quickstart

1. Create a file with `createFile`
2. Create some `Data`
3. Create a `DataWriter`
4. Write the data to a file
5. Create a schema
6. Create an iterator with `DataIterator`
7. Iterate over all value
8. Delete the file with `deleteFile`

Here an example of how to use it:
```zig
const std = @import("std");

pub fn main() anyerror!void {
    const allocator = std.testing.allocator;

    try std.fs.cwd().makeDir("tmp");
    const dir = try std.fs.cwd().openDir("tmp", .{});

    // 1. Create a file
    try createFile("test", dir);

    // 2. Create some Data
    const data = [_]Data{
        Data.initInt(1),
        Data.initFloat(3.14159),
        Data.initInt(-5),
        Data.initStr("Hello world"),
        Data.initBool(true),
        Data.initDate("2021/01/01"),
        Data.initTime("12:42:09.812"),
        Data.initDateTime("2021/01/01-12:42:09.812"),
    };

    // 3. Create a DataWriter
    var dwriter = try DataWriter.init("test", dir);
    defer dwriter.deinit(); // This just close the file

    // 4. Write some data
    try dwriter.write(&data);
    try dwriter.write(&data);
    try dwriter.write(&data);
    try dwriter.write(&data);
    try dwriter.write(&data);
    try dwriter.write(&data);
    try dwriter.flush(); // Dont forget to flush !

    // 5. Create a schema
    // A schema is how the data is organised in the file and how the iterator will parse it. If you are wrong here, it will return wrong/random data
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

    // 6. Create a DataIterator
    var iter = try DataIterator.init(allocator, "test", dir, schema);
    defer iter.deinit();

    // 7. Iterate over data
    while (try iter.next()) |row| {
        std.debug.print("Row {d}: {any}\n", .{ row });
    }

    // 8. Delete the file (Optional ofc)
    try deleteFile("test", dir);
    try std.fs.cwd().deleteDir("tmp");
}
```

# Benchmark

Done on a AMD Ryzen 7 7800X3D with a Samsung SSD 980 PRO 2TB (up to 7,000/5,100MB/s for read/write speed).

| Rows | Write Time (ms) | Average Write Time (μs) | Read Time (ms) | Average Read Time (μs) | File Size (kB) |
| --- | --- | --- | --- | --- | --- |
| 1         | 0.01      | 13.63 | 0.01      | 13.41 | 0.048 |
| 10        | 0.01      | 1.69  | 0.02      | 1.85  | 0.48  |
| 100       | 0.04      | 0.49  | 0.07      | 0.67  | 4.8   |
| 1000      | 0.38      | 0.38  | 0.64      | 0.64  | 48    |
| 10000     | 3.66      | 0.37  | 5.69      | 0.57  | 480   |
| 100000    | 36.39     | 0.36  | 57.35     | 0.57  | 4800  |
| 1000000   | 361.41    | 0.36  | 566.12    | 0.57  | 48000 |

TODO: Benchmark on my laptop and maybe on some cloud VM.

Data use:
```zig
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
```

I am happy with the result. I plan to use it in my database ZipponDB and to limit each file size to around 5-10MB, and then use one thread per file.
So it should be fairly fast.

# Importing the package

TODO

## What you can't do

You can't update the file. You gonna need to implement that yourself. The easier way (and only I know), is to parse the entier file and write it into another.

I will give an example of how I do it.
