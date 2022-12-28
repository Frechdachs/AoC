const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const input = @embedFile("input/04");
const test_input = @embedFile("input/04test");

const Range = util.Range(usize);


fn parseInput(allocator: Allocator, raw: []const u8) [][2]Range
{
    var ranges = List([2]Range).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var it2 = tokenize(u8, line, "-,");
        const s1 = parseInt(usize, it2.next().?, 10) catch unreachable;
        const e1 = parseInt(usize, it2.next().?, 10) catch unreachable;
        const s2 = parseInt(usize, it2.next().?, 10) catch unreachable;
        const e2 = parseInt(usize, it2.next().?, 10) catch unreachable;

        ranges.append(.{
            Range{ .start = s1, .end = e1 },
            Range{ .start = s2, .end = e2 },
        }) catch unreachable;
    }

    return ranges.toOwnedSlice();
}

fn part1(ranges: [][2]Range) usize
{
    var accum: usize = 0;

    for (ranges) |range| {
        accum += @boolToInt(
            range[0].containsRange(range[1]) or
            range[1].containsRange(range[0])
        );
    }

    return accum;
}

fn part2(ranges: [][2]Range) usize
{
    var accum: usize = 0;

    for (ranges) |range| {
        accum += @boolToInt(range[0].overlaps(range[1]));
    }

    return accum;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const ranges = parseInput(arena.allocator(), input);
    const p1 = part1(ranges);
    const p2 = part2(ranges);

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

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var inp: [][2]Range = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 1000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
        if (i >= warmup) timer.reset();
        p1 = part1(inp);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
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

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part1(inp) == 2);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part2(inp) == 4);
}