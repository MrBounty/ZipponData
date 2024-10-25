# ZipponData

ZipponData is a library developped in the context of ZipponDB.

The library intent to create a simple way to store data and parse data from a file in the most efficient way possible. 

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

Done on a AMD Ryzen 7 7800X3D.

| Rows | Write Time (ms) | Average Write Time (μs) | Read Time (ms) | Average Read Time (μs) | File Size (B) |
| --- | --- | --- | --- | --- | --- |
| 1         | 0.013630      | 13.63 | 0.013410      | 13.41 | 48        |
| 10        | 0.016930      | 1.69  | 0.018460      | 1.85  | 480       |
| 100       | 0.048750      | 0.49  | 0.067409      | 0.67  | 4800      |
| 1000      | 0.380299      | 0.38  | 0.638688      | 0.64  | 48000     |
| 10000     | 3.666838      | 0.37  | 5.691091      | 0.57  | 480000    |
| 100000    | 36.396625     | 0.36  | 57.348992     | 0.57  | 4800000   |
| 1000000   | 361.419023    | 0.36  | 566.124408    | 0.57  | 48000000  |

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
