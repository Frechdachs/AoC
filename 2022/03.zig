const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const parser = @import("parser.zig");
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const input = @embedFile("input/03");
const test_input = @embedFile("input/03test");


inline fn priority(item: u8) usize
{
    return switch (item) {
        'a'...'z' => item - 'a',
        'A'...'Z' => item - 'A' + 26,
        else => unreachable,
    };
}

fn parseInput(allocator: Allocator, raw: []const u8) []BitSet(64)
{
    var sacks = List(BitSet(64)).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |sack| {
        var sackset = BitSet(64).initEmpty();
        for (sack[0..sack.len / 2]) |item| {
            sackset.set(priority(item));
        }
        sacks.append(sackset) catch unreachable;

        sackset = BitSet(64).initEmpty();
        for (sack[sack.len / 2..]) |item| {
            sackset.set(priority(item));
        }
        sacks.append(sackset) catch unreachable;
    }

    return sacks.toOwnedSlice();
}

fn part1(sacks: []BitSet(64)) usize
{
    var accum: usize = 0;

    const masks = @ptrCast([]u64, sacks);
    var i: usize = 1;
    while (i < masks.len) : (i += 2) {
        const s = masks[i - 1] & masks[i];

        accum += 1 + @ctz(s);
    }

    return accum;
}

fn part2(sacks: []BitSet(64)) usize
{
    var accum: usize = 0;

    const masks = @ptrCast([]u64, sacks);
    var i: usize = 5;
    while (i < masks.len) : (i += 6) {
        const s1 = masks[i - 5] | masks[i - 4];
        const s2 = masks[i - 3] | masks[i - 2];
        const s3 = masks[i - 1] | masks[i];

        accum += 1 + @ctz(s1 & s2 & s3);
    }

    return accum;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const sacks = parseInput(arena.allocator(), input);
    const p1 = part1(sacks);
    const p2 = part2(sacks);

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

    var i: u32 = 0;
    var inp: []BitSet(64) = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    var warmup: u32 = 100;
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

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark to get optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part1(inp) == 157);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part2(inp) == 70);
}