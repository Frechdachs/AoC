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

const INPUT_PATH = "input/06";


const Parsed = struct {
    map: [][]const u8,
    guard: Guard,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.map);
    }
};

const Guard = struct {
    pos: [2]usize,
    dir: u2,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = List([]const u8).init(allocator);
    var it = tokenize(u8, raw, "\n");

    var guard: Guard = undefined;
    var y: usize = 0;
    while (it.next()) |line| : (y += 1) {
        const x_maybe = std.mem.indexOfScalar(u8, line, '^');
        if (x_maybe) |x| {
            guard = .{
                .pos = .{ x, y },
                .dir = 0,
            };
        }
        map.append(line) catch unreachable;
    }

    return .{
        .map = map.toOwnedSlice() catch unreachable,
        .guard = guard,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const map = parsed.map;
    var guard = parsed.guard;

    var seen = Map([2]usize, void).init(parsed.allocator);
    defer seen.deinit();

    while (step(map, &guard, &seen)) continue;

    return seen.count();
}

fn part2(parsed: Parsed) usize
{
    const map = parsed.map;
    const guard_start = parsed.guard;

    var seen = Map([2]usize, void).init(parsed.allocator);
    defer seen.deinit();

    var accum: usize = 0;
    var guard = guard_start;
    var guard_prev = guard_start;
    var seen_candidate = Map(Guard, void).init(parsed.allocator);
    defer seen_candidate.deinit();
    while (step(map, &guard, &seen)) {
        if (!seen.contains(guard.pos) and !std.mem.eql(usize, &guard.pos, &guard_prev.pos) and !std.mem.eql(usize, &guard.pos, &guard_start.pos)) {
            var guard_candidate = guard_start;
            const obstacle = guard.pos;
            inner: {
                while (
                    step2(map, &guard_candidate, &seen_candidate, obstacle) catch {
                        accum += 1;
                        break :inner;
                    }
                ) continue;
            }
            seen_candidate.clearRetainingCapacity();
        }
        guard_prev = guard;
    }

    return accum;
}

fn step(map: [][]const u8, guard: *Guard, seen: *Map([2]usize, void)) bool
{
    seen.put(guard.pos, {}) catch unreachable;
    const x = guard.pos[0];
    const y = guard.pos[1];
    var x_new = x;
    var y_new = y;

    switch (guard.dir) {
        0 => {
            if (y == 0) return false;
            y_new = y - 1;
        },
        1 => {
            if (x >= map[0].len - 1) return false;
            x_new = x + 1;
        },
        2 => {
            if (y >= map.len - 1) return false;
            y_new = y + 1;
        },
        3 => {
            if (x == 0) return false;
            x_new = x - 1;
        },
    }
    if (map[y_new][x_new] == '#') {
        guard.dir +%= 1;
    } else {
        guard.pos = .{ x_new, y_new };
    }

    return true;
}

fn step2(map: [][]const u8, guard: *Guard, seen: *Map(Guard, void), obstacle: ?[2]usize) !bool
{
    const x = guard.pos[0];
    const y = guard.pos[1];
    var x_new = x;
    var y_new = y;

    switch (guard.dir) {
        0 => {
            if (y == 0) return false;
            y_new = y - 1;
        },
        1 => {
            if (x >= map[0].len - 1) return false;
            x_new = x + 1;
        },
        2 => {
            if (y >= map.len - 1) return false;
            y_new = y + 1;
        },
        3 => {
            if (x == 0) return false;
            x_new = x - 1;
        },
    }
    if (map[y_new][x_new] == '#' or obstacle != null and std.mem.eql(usize, &.{ x_new, y_new }, &obstacle.?)) {
        guard.dir +%= 1;
    } else {
        guard.pos = .{ x_new, y_new };

        if (seen.contains(guard.*)) return error.Loop;
        seen.put(guard.*, {}) catch unreachable;
    }

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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 10000, 10);
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

    try std.testing.expectEqual(@as(usize, 41), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 6), part2(parsed));
}