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

const input = @embedFile("input/01");
const test_input = @embedFile("input/01test");


fn parseInput(allocator: Allocator, raw: []const u8) []usize
{
    var elves = List(usize).init(allocator);

    var it = split(u8, raw, "\n\n");
    var i: usize = 0;
    while (it.next()) |batch| : (i += 1) {
        elves.append(0) catch unreachable;
        var it2 = tokenize(u8, batch, "\n");
        while (it2.next()) |calories| {
            elves.items[i] += parseInt(usize, calories, 10) catch unreachable;
        }
    }

    return elves.toOwnedSlice();
}

fn part1(elves: []usize) usize
{
    var max: usize = 0;
    for (elves) |calories| {
        if (calories > max) max = calories;
    }

    return max;
}

fn part2(elves: []usize) usize
{
    _ = util.selectNthUnstable(elves, elves.len - 3);

    return util.sum(elves[elves.len - 3..]);
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const elves = parseInput(arena.allocator(), input);
    const p1 = part1(elves);
    const p2 = part2(elves);

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
    var inp: []usize = undefined;
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
    try std.testing.expect(part1(inp) == 24000);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const inp = parseInput(arena.allocator(), test_input);
    try std.testing.expect(part2(inp) == 45000);
}