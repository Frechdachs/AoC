const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.mem.sort;
const parseInt = std.fmt.parseInt;
const parseUnsigned = std.fmt.parseUnsigned;
const parseFloat = std.fmt.parseFloat;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/11";


const Parsed = struct {
    stones: []usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.stones);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var stones = List(usize).init(allocator);

    var it = tokenize(u8, raw, " \n");

    while (it.next()) |num| {
        stones.append(parseInt(usize, num, 10) catch unreachable) catch unreachable;
    }

    return .{
        .stones = stones.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    return simulate(25, parsed);
}

fn part2(parsed: Parsed) usize
{
    return simulate(75, parsed);
}

fn simulate(comptime steps: usize, parsed: Parsed) usize
{
    const stones = parsed.stones;
    var seen = Map([2]usize, usize).init(parsed.allocator);
    defer seen.deinit();

    var accum: usize = 0;
    for (stones) |stone| {
        accum += blink(steps, stone, &seen);
    }

    return accum;
}

fn blink(step: usize, stone: usize, seen: *Map([2]usize, usize)) usize
{
    if (step == 0) return 1;

    if (stone == 0) {
        return blink(step - 1, 1, seen);
    }

    var temp = stone;
    var digits: usize = 0;
    while (temp != 0) : (temp /= 10) digits += 1;

    if (digits & 0b1 != 0) {
        return blink(step - 1, stone * 2024, seen);
    }

    if (seen.get(.{ stone, step })) |stone_count| return stone_count;

    const half_magnitude = std.math.pow(usize, 10, digits / 2);
    const stone_l = stone / half_magnitude;
    const stone_r = stone - stone_l * half_magnitude;
    const stone_count = blink(step - 1, stone_l, seen) + blink(step - 1, stone_r, seen);
    seen.put(.{ stone, step }, stone_count) catch unreachable;

    return stone_count;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;

    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    const p1 = part1(parsed);
    const p2 = part2(parsed);

    print("Part1: {}\n", .{ p1 });
    print("Part2: {}\n", .{ p2 });

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 100);
}

//
// Tests
//
test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 55312), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 65601038650482), part2(parsed));
}