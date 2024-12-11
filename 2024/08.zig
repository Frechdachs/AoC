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

const INPUT_PATH = "input/08";


const Parsed = struct {
    antennas: Map(u8, List([2]isize)),
    width: usize,
    height: usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        var it = self.antennas.iterator();
        while (it.next()) |entry| {
           entry.value_ptr.deinit();
        }
        self.antennas.deinit();
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var antennas = Map(u8, List([2]isize)).init(allocator);
    var it = tokenize(u8, raw, "\n");

    var y: usize = 0;
    var width: usize = 0;
    while (it.next()) |line| : (y += 1) {
        width = line.len;
        for (line, 0..) |c, x| {
            if (c == '.') continue;
            const result = antennas.getOrPut(c) catch unreachable;
            if (!result.found_existing) {
                result.value_ptr.* = List([2]isize).init(allocator);
            }
            result.value_ptr.append(.{ @intCast(x), @intCast(y) }) catch unreachable;
        }
    }

    return .{
        .antennas = antennas,
        .width = width,
        .height = y,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const antennas = parsed.antennas;
    const width = parsed.width;
    const height = parsed.height;

    var antinodes = Map([2]isize, void).init(parsed.allocator);
    defer antinodes.deinit();

    var it = antennas.iterator();
    while (it.next()) |entry| {
        const positions = entry.value_ptr;

        for (positions.items, 0..) |position1, i| {
            const Vec2i = @Vector(2, isize);
            for (positions.items[i + 1..]) |position2| {
                const diff = @as(Vec2i, position1) - position2;
                const antinode1 = position1 + diff;
                const antinode2 = position2 - diff;
                if (checkBounds(antinode1, width, height)) antinodes.put(antinode1, {}) catch unreachable;
                if (checkBounds(antinode2, width, height)) antinodes.put(antinode2, {}) catch unreachable;
            }
        }
    }

    return antinodes.count();
}

fn part2(parsed: Parsed) usize
{
    const antennas = parsed.antennas;
    const width = parsed.width;
    const height = parsed.height;

    var antinodes = Map([2]isize, void).init(parsed.allocator);
    defer antinodes.deinit();

    var it = antennas.iterator();
    while (it.next()) |entry| {
        const positions = entry.value_ptr;

        for (positions.items, 0..) |position1, i| {
            const Vec2i = @Vector(2, isize);
            for (positions.items[i + 1..]) |position2| {
                const diff = @as(Vec2i, position1) - position2;
                var antinode1 = position1;
                while (checkBounds(antinode1, width, height)) {
                    antinodes.put(antinode1, {}) catch unreachable;
                    antinode1 = antinode1 + diff;
                }
                var antinode2 = position2;
                while (checkBounds(antinode2, width, height)) {
                    antinodes.put(antinode2, {}) catch unreachable;
                    antinode2 = antinode2 - diff;
                }
            }
        }
    }

    return antinodes.count();
}

inline fn checkBounds(antinode: [2]isize, width: usize, height: usize) bool
{
    if (antinode[0] < 0 or antinode[0] >= width) return false;
    if (antinode[1] < 0 or antinode[1] >= height) return false;

    return true;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 100000, 100000);
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

    try std.testing.expectEqual(@as(usize, 14), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 34), part2(parsed));
}