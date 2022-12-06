const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const splitBackwards = std.mem.splitBackwards;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const parser = @import("parser.zig");
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const INPUT_FILE_NAME = "input/06";
const TEST_INPUT_FILE_NAME = "input/06test";


fn parseInput(allocator: Allocator, raw: []const u8) []const u8
{
    _ = allocator;

    return raw;
}

/// O(n*m) solution
/// Faster for part 1, but slower for part 2
inline fn findMarker(comptime marker_len: usize, stream: []const u8) usize
{
    var i: usize = marker_len;
    while (i <= stream.len) : (i += 1) {
        var bitset = BitSet(32).initEmpty();

        for (stream[i - marker_len..i]) |c| {
            bitset.set(c - 'a');
        }

        if (bitset.count() == marker_len) return i;
    }

    return 0;
}

/// O(n) solution
/// Faster for part 2, but slower for part 1
inline fn findMarker2(comptime marker_len: usize, stream: []const u8) usize
{
    var counters: [26]usize = .{ 0 } ** 26;
    var dups: usize = 0;

    var i: usize = 0;
    while (i < stream.len) : (i += 1) {
        const window_end_idx = stream[i] - 'a';
        counters[window_end_idx] += 1;
        if (counters[window_end_idx] > 1) dups += 1;

        if (i < marker_len - 1) continue;

        if (i >= marker_len) {
            const window_start_idx = stream[i - marker_len] - 'a';
            counters[window_start_idx] -= 1;
            if (counters[window_start_idx] > 0) dups -= 1;
        }

        if (dups == 0) return i + 1;
    }

    return 0;
}

fn part1(stream: []const u8) usize
{
    return findMarker(4, stream);
}

fn part2(stream: []const u8) usize
{
    return findMarker2(14, stream);
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), INPUT_FILE_NAME, 1024 * 1024);

    const stream = parseInput(arena.allocator(), input);
    const p1 = part1(stream);
    const p2 = part2(stream);

    print("Part1: {}\n", .{ p1 });
    print("Part2: {}\n", .{ p2 });

    try benchmark();
}


//
// Benchmarks and tests
//
fn benchmark() !void
{
    const allocator = std.heap.c_allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_FILE_NAME, 1024 * 1024);
    defer allocator.free(input);

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var inp: []const u8 = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 10000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        inp = parseInput(allocator, input);
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        if (i >= warmup) timer.reset();
        p1 = part1(inp);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        if (i >= warmup) timer.reset();
        p2 = part2(inp);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_FILE_NAME, 1024 * 1024);

    const inp = parseInput(arena.allocator(), input);
    try std.testing.expect(part1(inp) == 7);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_FILE_NAME, 1024 * 1024);

    const inp = parseInput(arena.allocator(), input);
    try std.testing.expect(part2(inp) == 19);
}