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

pub inline fn abs(i: anytype) @TypeOf(i)
{
    comptime assert(@typeInfo(@TypeOf(i)).Int.signedness == .signed);
    assert(i != std.math.minInt(@TypeOf(i)));

    const shift = @typeInfo(@TypeOf(i)).Int.bits - 1;

    return i + (i >> shift) ^ (i >> shift);
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

pub fn lcm(a: anytype, b: @TypeOf(a)) @TypeOf(a)
{
    const type_info = @typeInfo(@TypeOf(a));
    comptime assert(type_info == .Int or type_info == .ComptimeInt);
    assert(a >= 0 and b >= 0);
    assert(a > 0 or b > 0);

    return a * @divTrunc(b, gcd(a, b));
}

pub fn gcd(a: anytype, b: @TypeOf(a)) @TypeOf(a)
{
    const type_info = @typeInfo(@TypeOf(a));
    comptime assert(type_info == .Int or type_info == .ComptimeInt);
    assert(a >= 0 and b >= 0);
    assert(a > 0 or b > 0);

    var i = a;
    var j = b;
    if (i < j) std.mem.swap(@TypeOf(a), &i, &j);
    while (j != 0) {
        i = @rem(i, j);
        std.mem.swap(@TypeOf(a), &i, &j);
    }

    return i;
}

/// Quickselect selection algorithm
/// As described in https://en.wikipedia.org/wiki/Quickselect
pub fn selectNthUnstable(slice: anytype, n: usize) @typeInfo(@TypeOf(slice)).Pointer.child
{
    assert(slice.len > n);

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

        pub fn contains(self: Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn clone(self: Self) Allocator.Error!Self {
            return .{
                .map = try self.map.clone(),
                .allocator = self.allocator,
            };
        }
    };
}

pub fn benchmark(
    comptime input_path: []const u8,
    comptime parseFn: anytype,
    comptime part1Fn: anytype,
    comptime part2Fn: anytype,
    comptime parse_count: u32,
    comptime part1_count: u32,
    comptime part2_count: u32,
) !void
{
    const allocator = std.heap.c_allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, input_path, 1024 * 1024);
    defer allocator.free(input);

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var parsed: @typeInfo(@TypeOf(parseFn)).Fn.return_type.? = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < parse_count + warmup) : (i += 1) {
        if (i == warmup) timer.reset();
        parsed = parseFn(allocator, input);
        parsed.deinit();
        if (i >= warmup) parse_time += timer.lap();
    }
    parse_time /= i - warmup;

    parsed = parseFn(allocator, input);
    defer parsed.deinit();

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: @typeInfo(@TypeOf(part1Fn)).Fn.return_type.? = undefined;
    var part1_time: u64 = 0;
    while (i < part1_count + warmup) : (i += 1) {
        if (i == warmup) timer.reset();
        p1 = part1Fn(parsed);
        if (i >= warmup) part1_time += timer.lap();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: @typeInfo(@TypeOf(part2Fn)).Fn.return_type.? = undefined;
    var part2_time: u64 = 0;
    while (i < part2_count + warmup) : (i += 1) {
        if (i == warmup) timer.reset();
        p2 = part2Fn(parsed);
        if (i >= warmup) part2_time += timer.lap();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    printBenchmark(parse_time, part1_time, part2_time);
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

    var i: u64 = @intCast(if (negative) -integer else integer);

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