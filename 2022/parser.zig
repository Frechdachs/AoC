// Taken from https://github.com/SpexGuy/Advent2021/blob/bebd49da9a88ae795cedff830a4d95e1209d3dab/src/util.zig
// Modified to take an allocator and to ensure compatibility with Zig 0.10.0

const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;
const Str = []const u8;


// Add utility functions here
pub const default_delims = " ,:(){}<>[]!\r\n\t";

pub fn parseLines(comptime T: type, allocator: Allocator, text: []const u8) []T {
    return parseLinesDelim(T, allocator, text, default_delims);
}

pub fn parseLinesDelim(comptime T: type, allocator: Allocator, text: []const u8, delims: []const u8) []T {
    var list = List(T).init(allocator);
    var lines = tokenize(u8, text, "\r\n");
    var linenum: u32 = 1;
    while (lines.next()) |line| : (linenum += 1) {
        if (line.len == 0) { continue; }
        list.append(parseLine(T, allocator, line, delims, linenum)) catch unreachable;
    }
    return list.toOwnedSlice();
}

pub fn parse(comptime T: type, allocator: Allocator, str: []const u8) T {
    return parseLine(T, allocator, str, default_delims, 1337);
}

pub fn parseLine(comptime T: type, allocator: Allocator, str: []const u8, delims: []const u8, linenum: u32) T {
    var it = std.mem.tokenize(u8, str, delims);
    const result = parseNext(T, allocator, &it, linenum).?;
    if (it.next()) |next| {
        debugError("Extra token on line {}: '{s}'", .{linenum, next});
    }
    return result;
}

pub fn parseNext(comptime T: type, allocator: Allocator, it: *std.mem.TokenIterator(u8), linenum: u32) ?T {
    if (T == []const u8) return it.next();
    switch (@typeInfo(T)) {
        .Int => {
            const token = it.next() orelse return null;
            return parseInt(T, token, 10)
                catch |err| debugError("invalid integer '{s}' on line {}, err={}", .{token, linenum, err});
        },
        .Float => {
            const token = it.next() orelse return null;
            return parseFloat(T, token)
                catch |err| debugError("invalid float '{s}' on line {}, err={}", .{token, linenum, err});
        },
        .Enum => {
            const token = it.next() orelse return null;
            if (token.len <= 10) {
                var token_buf: [10]u8 = .{0} ** 10;
                std.mem.copy(u8, &token_buf, token[0..]);
                if (token_buf[0] >= 'a') {
                    token_buf[0] -= 32;
                    const result = strToEnum(T, token_buf[0..token.len]);
                    if (result) |e| return e;
                }
            }
            return strToEnum(T, token)
                orelse debugError("cannot convert '{s}' to enum {s} on line {}", .{token, @typeName(T), linenum});
        },
        .Array => |arr| {
            var result: T = undefined;
            for (result) |*item, i| {
                item.* = parseNext(arr.child, allocator, it, linenum) orelse {
                    if (i == 0) { return null; }
                    debugError("Only found {} of {} items in array, on line {}\n", .{i, arr.len, linenum});
                };
            }
            return result;
        },
        .Struct => |str| {
            var result: T = undefined;
            var exit: bool = false; // workaround for control flow in inline for issues
            inline for (str.fields) |field, i| {
                parseNextStructField(&result, allocator, field, i, &exit, it, linenum);
            }
            if (exit) return null;
            return result;
        },
        .Optional => |opt| {
            return @as(T, parseNext(opt.child, allocator, it, linenum));
        },
        .Pointer => |ptr| {
            if (ptr.size == .Slice) {
                var results = List(ptr.child).init(allocator);
                while (parseNext(ptr.child, allocator, it, linenum)) |value| {
                    results.append(value) catch unreachable;
                }
                return results.toOwnedSlice();
            } else @compileError("Unsupported type " ++ @typeName(T));
        },
        else => @compileError("Unsupported type " ++ @typeName(T)),
    }
}

fn parseNextStructField(
    result: anytype,
    allocator: Allocator,
    comptime field: std.builtin.Type.StructField,
    comptime i: usize,
    exit: *bool,
    it: *std.mem.TokenIterator(u8),
    linenum: u32,
) void {
    if (!exit.*) {
        if (field.name[0] == '_') {
            if (field.default_value) |default_value| {
                @field(result, field.name) = @ptrCast(*const field.field_type, default_value).*;
            } else {
                @field(result, field.name) = undefined;
            }
        } else if (parseNext(field.field_type, allocator, it, linenum)) |value| {
            @field(result, field.name) = value;
        } else if (field.default_value) |default| {
            @field(result, field.name) = default;
        } else if (i == 0) {
            exit.* = true;
        } else if (comptime std.meta.trait.isSlice(field.field_type)) {
            @field(result, field.name) = &.{};
        } else {
            debugError("Missing field {s}.{s} and no default, on line {}", .{@typeName(@TypeOf(result)), field.name, linenum});
        }
    }
}

test "parseLine" {
    //var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa_impl.allocator();
    const allocator = std.testing.allocator;

    try std.testing.expect(parseLine(u32, allocator, " 42 ", " ,", @src().line) == 42);
    try std.testing.expect(parseLine(f32, allocator, " 0.5", " ,", @src().line) == 0.5);
    try std.testing.expect(parseLine(f32, allocator, "42", " ,", @src().line) == 42);
    try std.testing.expect(parseLine(enum { foo, bar }, allocator, "foo", " ,", @src().line) == .foo);
    try std.testing.expect(eql(u16, &parseLine([3]u16, allocator, " 2, 15 4 ", " ,", @src().line), &[_]u16{2, 15, 4}));
    var line = parseLine([]u16, allocator, " 2, 15 4 ", " ,", @src().line);
    try std.testing.expect(eql(u16, line, &[_]u16{2, 15, 4}));
    allocator.free(line);  // Slices (except []const u8) have to be freed)
    try std.testing.expect(parseLine(?f32, allocator, "42", " ,", @src().line).? == 42);
    try std.testing.expect(parseLine(?f32, allocator, "", " ,", @src().line) == null);
    try std.testing.expect(eql(u8, parseLine([]const u8, allocator, "foob", " ,", @src().line), "foob"));
    try std.testing.expect(eql(u8, parseLine([]const u8, allocator, "foob", " ,", @src().line), "foob"));
    try std.testing.expect(eql(u8, parseLine(Str, allocator, "foob", " ,", @src().line), "foob"));

    const T = struct {
        int: i32,
        float: f32,
        enumeration: enum{ foo, Bar, baz },
        _first: bool = true,
        array: [3]u16,
        string: []const u8,
        _skip: *@This(),
        optional: ?u16,
        tail: [][]const u8,
    };

    {
        const a = parseLine(T, allocator, "4: 5.0, bar 4, 5, 6 badaboom", ":, ", @src().line);
        try std.testing.expect(a.int == 4);
        try std.testing.expect(a.float == 5.0);
        try std.testing.expect(a.enumeration == .Bar);
        try std.testing.expect(a._first == true);
        try std.testing.expect(eql(u16, &a.array, &[_]u16{4, 5, 6}));
        try std.testing.expect(eql(u8, a.string, "badaboom"));
        try std.testing.expect(a.optional == null);
        try std.testing.expect(a.tail.len == 0);
    }

    {
        const a = parseLine(T, allocator, "-5: 3: foo 4, 5, 6 booptroop 53", ":, ", @src().line);
        try std.testing.expect(a.int == -5);
        try std.testing.expect(a.float == 3);
        try std.testing.expect(a.enumeration == .foo);
        try std.testing.expect(a._first == true);
        try std.testing.expect(eql(u16, &a.array, &[_]u16{4, 5, 6}));
        try std.testing.expect(eql(u8, a.string, "booptroop"));
        try std.testing.expect(a.optional.? == 53);
        try std.testing.expect(a.tail.len == 0);
    }

    {
        const a = parseLine(T, allocator, "+15: -10: baz 5, 6, 7 skidoosh 82 ruby supports bare words", ":, ", @src().line);
        try std.testing.expect(a.int == 15);
        try std.testing.expect(a.float == -10);
        try std.testing.expect(a.enumeration == .baz);
        try std.testing.expect(a._first == true);
        try std.testing.expect(eql(u16, &a.array, &[_]u16{5, 6, 7}));
        try std.testing.expect(eql(u8, a.string, "skidoosh"));
        try std.testing.expect(a.optional.? == 82);
        try std.testing.expect(a.tail.len == 4);
        try std.testing.expect(eql(u8, a.tail[0], "ruby"));
        try std.testing.expect(eql(u8, a.tail[1], "supports"));
        try std.testing.expect(eql(u8, a.tail[2], "bare"));
        try std.testing.expect(eql(u8, a.tail[3], "words"));

        allocator.free(a.tail);  // The outer slice of [][]const u8 has to be freed
    }

    //print("All tests passed.\n", .{});
}

inline fn debugError(comptime fmt: []const u8, args: anytype) noreturn {
    if (std.debug.runtime_safety) {
        std.debug.panic(fmt, args);
    } else {
        unreachable;
    }
}

// Useful stdlib functions
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;
const eql = std.mem.eql;

const strToEnum = std.meta.stringToEnum;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const min = std.math.min;
const min3 = std.math.min3;
const max = std.math.max;
const max3 = std.math.max3;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.sort;
const asc = std.sort.asc;
const desc = std.sort.desc;