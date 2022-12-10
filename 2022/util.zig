const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;

const List = std.ArrayList;
const Map = std.AutoHashMap;


//
// Some utility functions/types that make writing AoC solutions a bit more comfortable
//


pub fn Range(comptime T: type) type
{
    return struct {
        start: T,
        end: T,

        const Self = @This();

        pub fn contains(self: *const Self, n: T) bool {
            return n >= self.start and n <= self.end;
        }

        pub fn containsRange(self: *const Self, other: Self) bool {
            return self.start >= other.start and self.end <= other.end;
        }

        pub fn overlaps(self: *const Self, other: Self) bool {
            return self.start <= other.end and self.end >= other.start;
        }
    };
}

pub inline fn absdiff(a: anytype, b: @TypeOf(a)) @TypeOf(a)
{
    if (a < b) return b - a else return a - b;
}

pub inline fn sum(items: anytype) switch (@typeInfo(@TypeOf(items))) {
    .Array => |arr| arr.child,
    .Pointer => |ptr| ptr.child,
    else => @compileError("sum: The type " ++ @typeName(@TypeOf(items)) ++ " is not supported."),
}
{
    const T = @TypeOf(items[0]);

    var accum: T = 0;
    for (items) |item| {
        accum += item;
    }

    return accum;
}

pub inline fn sumWrapping(items: anytype) switch (@typeInfo(@TypeOf(items))) {
    .Array => |arr| arr.child,
    .Pointer => |ptr| ptr.child,
    else => @compileError("sum: The type " ++ @typeName(@TypeOf(items)) ++ " is not supported."),
}
{
    const T = @TypeOf(items[0]);

    var accum: T = 0;
    for (items) |item| {
        accum +%= item;
    }

    return accum;
}

pub inline fn product(items: anytype) switch (@typeInfo(@TypeOf(items))) {
    .Array => |arr| arr.child,
    .Pointer => |ptr| ptr.child,
    else => @compileError("product: The type " ++ @typeName(@TypeOf(items)) ++ " is not supported."),
}
{
    const T = @TypeOf(items[0]);

    var prod: T = 1;
    for (items) |item| {
        prod *= item;
    }

    return prod;
}

/// Quickselect selection algorithm
/// As described in https://en.wikipedia.org/wiki/Quickselect
pub fn selectNthUnstable(slice: anytype, n: usize) @typeInfo(@TypeOf(slice)).Pointer.child
{
    var l: usize = 0;
    var r: usize = slice.len - 1;
    while (l != r) {
        var p_idx = l + (r - l + 1) / 2;
        p_idx = partition(slice, l, r, p_idx);
        if (n == p_idx) {
            return slice[n];
        } else if (n < p_idx) {
            r = p_idx - 1;
        } else {
            l = p_idx + 1;
        }
    }
    return slice[l];
}

fn partition(slice: anytype, l: usize, r: usize, p_idx: usize) usize
{
    const T = @typeInfo(@TypeOf(slice)).Pointer.child;
    const p_value = slice[p_idx];
    std.mem.swap(T, &slice[p_idx], &slice[r]);
    var s_idx = l;
    var i: usize = l;
    while (i < r) : (i += 1) {
        if (slice[i] < p_value) {
            std.mem.swap(T, &slice[s_idx], &slice[i]);
            s_idx += 1;
        }
    }
    std.mem.swap(T, &slice[s_idx], &slice[r]);
    return s_idx;
}

/// Infinite grid based on a HashMap
pub fn Grid(comptime T: type) type
{
    const K = [2]isize;

    return struct {
        map: Map(K, T),
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .map = Map(K, T).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
            self.* = undefined;
        }

        pub fn get(self: Self, key: K) ?T {
            return self.map.get(key);
        }

        pub fn put(self: *Self, key: K, value: T) Allocator.Error!void {
            return self.map.put(key, value);
        }

        pub fn putNoClobber(self: *Self, key: K, value: T) Allocator.Error!void {
            return self.map.putNoClobber(key, value);
        }

        pub fn count(self: Self) Map(K, T).Size {
            return self.map.count();
        }
    };
}

pub fn printBenchmark(parse_time: anytype, part1_time: anytype, part2_time: anytype) void
{
    print("Benchmarks: parsing: ", .{});
    printIntegerWithSeparator(parse_time);
    print(" ns, part1: ", .{});
    printIntegerWithSeparator(part1_time);
    print(" ns, part2: ", .{});
    printIntegerWithSeparator(part2_time);
    print(" ns\n", .{});
}

pub fn printIntegerWithSeparator(integer: anytype) void
{
    const type_info = @typeInfo(@TypeOf(integer));
    comptime assert(type_info == .Int or type_info == .ComptimeInt);

    const negative = integer < 0;

    var i = @intCast(u64, if (negative) integer * -1 else integer);

    var div: u64 = 1;
    while (i / div > 999) div *= 1000;

    if (negative) print("-", .{});

    var first = true;
    while (div > 0) {
        const d = i / div;
        if (first) {
            print("{}", .{ d });
        } else {
            print("{:0>3}", .{ d });
        }
        if (div > 1) print(",", .{});
        i -= d * div;
        first = false;
        div /= 1000;
    }
}