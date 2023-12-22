const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.mem.sort;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/21";


const Parsed = struct {
    pos_start: [2]usize,
    map: [][]const Plot,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.map);
    }
};

const Plot = enum(u8) {
    garden = '.',
    rock = '#',
    start = 'S'
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = List([]const Plot).init(allocator);

    var line_length = std.mem.indexOf(u8, raw, "\n").?;

    var i: usize = 0;
    var y: usize = 0;
    while (i < raw.len) : ({ y += 1; i += line_length + 1; }) {
        const line = raw[i..i + line_length];
        map.append(@ptrCast(line)) catch unreachable;
    }

    const pos_start = .{ map.items.len / 2, map.items.len / 2 };
    assert(map.items[pos_start[0]][pos_start[1]] == .start);
    assert(pos_start[0] == (map.items.len - 1) / 2);
    assert(pos_start[1] == pos_start[0]);
    assert(map.items.len == map.items[0].len and map.items.len % 2 == 1);

    return .{
        .pos_start = pos_start,
        .map = map.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const pos_start = parsed.pos_start;
    const map = parsed.map;

    const required_steps: usize = 64;

    return getReachableGardens(parsed.allocator, required_steps, pos_start, map)[1];
}

fn part2(parsed: Parsed) usize
{
    const pos_start = parsed.pos_start;
    const map = parsed.map;

    const squares = getReachableGardens(parsed.allocator, map.len, pos_start, map);
    const diamonds = getReachableGardens(parsed.allocator, map.len / 2, pos_start, map);

    const corners: [2]usize = .{ squares[0] - diamonds[0], squares[1] - diamonds[1] };

    var steps: usize = 26501365 - map.len / 2;

    assert(steps % map.len == 0);

    var needed_squares: usize = 4;
    var accum: usize = squares[1];
    var idx: u1 = 0;
    var corner_counter: usize = 0;
    while (steps != 0) {
        accum += squares[idx] * needed_squares;

        idx +%= 1;
        needed_squares += 4;
        corner_counter += 1;
        steps -= map.len;
    }
    accum -= corners[idx +% 1] * (corner_counter + 1);
    accum += corners[idx] * corner_counter;

    return accum;
}

fn getReachableGardens(allocator: Allocator, required_steps: usize, pos_start: [2]usize, map: [][]const Plot) [2]usize
{
    var seen = Map([2]usize, void).init(allocator);
    defer seen.deinit();
    var queue = List([3]usize).init(allocator);
    defer queue.deinit();

    queue.append(.{ 0 } ++ pos_start) catch unreachable;

    var accum: [2]usize = .{ 0, 0 };
    while (queue.items.len > 0) {
        const value = queue.orderedRemove(0);
        const steps = value[0];
        const pos: [2]usize = .{ value[1], value[2] };
        if (steps > 0) accum[@intFromBool(steps % 2 == required_steps % 2)] += 1;
        if (steps == required_steps) continue;

        for (getNeighbors(pos, map)) |neighbor_maybe| {
            if (neighbor_maybe) |neighbor| {
                if (seen.contains(neighbor)) continue;
                queue.append(.{ steps + 1 } ++ neighbor) catch unreachable;
                seen.put(neighbor, {}) catch unreachable;
            }
        }
    }

    return accum;
}

fn getNeighbors(pos: [2]usize, map: [][]const Plot) [4]?[2]usize
{
    const y = pos[0];
    const x = pos[1];
    var neighbors: [4]?[2]usize = .{ null } ** 4;

    for (0..4) |i| {
        var neighbor: [2]usize = undefined;
        switch (i) {
            0 => {
                neighbor = .{ std.math.sub(usize, y, 1) catch continue, x };
            },
            1 => {
                neighbor = .{ y, x + 1 };
                if (neighbor[1] > map[0].len - 1) continue;
            },
            2 => {
                neighbor = .{ y + 1, x };
                if (neighbor[0] > map.len - 1) continue;
            },
            3 => {
                neighbor = .{ y, std.math.sub(usize, x, 1) catch continue };
            },
            else => unreachable
        }
        if (map[neighbor[0]][neighbor[1]] == .rock) continue;

        neighbors[i] = neighbor;
    }

    return neighbors;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    const p1 = part1(parsed);
    const p2 = part2(parsed);

    print("Part1: {}\n", .{ p1 });
    print("Part2: {}\n", .{ p2 });

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 1000);
}

//
// Tests
//
test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 3724), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 620348631910321), part2(parsed));
}