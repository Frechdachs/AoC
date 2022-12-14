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

const input = @embedFile("input/02");
const test_input = @embedFile("input/02test");


fn parseInput(allocator: Allocator, raw: []const u8) [][2]u8
{
    var guide = List([2]u8).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |nums| {
        guide.append(.{nums[0] - 'A', nums[2] - 'X'}) catch unreachable;
    }

    return guide.toOwnedSlice();
}

fn part1(guide: [][2]u8) usize
{
    var accum: usize = 0;

    for (guide) |strategy| {
        const other = strategy[0];
        const self = strategy[1];

        const outcome_table: [6]u8 = .{ 0, 6, 3 } ** 2;

        accum += 1 + self + outcome_table[other + 2 - self];
    }

    return accum;
}

fn part2(guide: [][2]u8) usize
{
    var accum: usize = 0;

    for (guide) |strategy| {
        const other = strategy[0];
        const self_idx = other + strategy[1];

        const self_table: [6]u8 = .{ 3, 1, 2 } ** 2;

        accum += self_table[self_idx] + 3 * strategy[1];
    }

    return accum;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const guide = parseInput(arena.allocator(), input);
    const p1 = part1(guide);
    const p2 = part2(guide);

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
    var inp: [][2]u8 = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 1000) : (i += 1) {
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
        parse_time += timer.lap();
    }
    parse_time /= i;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 1000) : (i += 1) {
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
        timer.reset();
        p1 = part1(inp);
        part1_time += timer.read();
    }
    part1_time /= i;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 1000) : (i += 1) {
        inp = parseInput(allocator, input);
        defer allocator.free(inp);
        timer.reset();
        p2 = part2(inp);
        part2_time += timer.read();
    }
    part2_time /= i;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark to get optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part1(inp) == 15);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part2(inp) == 12);
}