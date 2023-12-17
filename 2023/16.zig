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

const INPUT_PATH = "input/16";


const Parsed = struct {
    contraption: [][]const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.contraption);
    }
};

const Beam = struct {
    y: usize,
    x: usize,
    dir: Dir,
};

const Dir = enum(u32) {
    n = 1,
    e = 2,
    s = 4,
    w = 8,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var contraption = List([]const u8).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        contraption.append(line) catch unreachable;
    }

    return .{
        .contraption = contraption.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const contraption = parsed.contraption;

    return simulate(parsed.allocator, .{ .y = 0, .x = 0, .dir = .e }, contraption);
}

fn part2(parsed: Parsed) usize
{
    const contraption = parsed.contraption;

    var energized: usize = 0;

    for (0..contraption[0].len) |i| {
        energized = @max(
            energized,
            simulate(parsed.allocator, .{ .y = 0, .x = i, .dir = .s }, contraption)
        );
        energized = @max(
            energized,
            simulate(parsed.allocator, .{ .y = contraption.len - 1, .x = i, .dir = .n }, contraption)
        );
    }
    for (0..contraption.len) |i| {
        energized = @max(
            energized,
            simulate(parsed.allocator, .{ .y = i, .x = 0, .dir = .e }, contraption)
        );
        energized = @max(
            energized,
            simulate(parsed.allocator, .{ .y = i, .x = contraption[0].len - 1, .dir = .w }, contraption)
        );
    }

    return energized;
}

fn simulate(allocator: Allocator, beam_start: Beam, contraption: [][]const u8) usize
{
    var seen = allocator.alloc([]u32, contraption.len) catch unreachable;
    for (seen) |*row| {
        row.* = allocator.alloc(u32, contraption[0].len) catch unreachable;
        @memset(row.*, 0);
    }
    defer {
        for (seen) |row| allocator.free(row);
        allocator.free(seen);
    }

    var beams = List(Beam).init(allocator);
    defer beams.deinit();

    beams.append(beam_start) catch unreachable;

    while (beams.popOrNull()) |beam| {
        const beams_step = followBeam(beam, contraption, seen);
        for (beams_step) |beam_step_maybe| {
            if (beam_step_maybe) |beam_step| {
                beams.append(beam_step) catch unreachable;
            }
        }
    }

    var accum: usize = 0;

    for (seen) |row| {
        for (row) |value| {
            accum += @intFromBool(value != 0);
        }
    }

    return accum;
}

fn followBeam(beam: Beam, contraption: [][]const u8, seen: [][]u32) [2]?Beam
{
    seen[beam.y][beam.x] |= @intFromEnum(beam.dir);

    const x = beam.x;
    const y = beam.y;
    const dir = beam.dir;

    return switch (contraption[y][x]) {
        '.' => .{ stepBeam(x, y, dir, seen), null },
        '/' => switch (dir) {
            .n => .{ stepBeam(x, y, .e, seen), null },
            .e => .{ stepBeam(x, y, .n, seen), null },
            .s => .{ stepBeam(x, y, .w, seen), null },
            .w => .{ stepBeam(x, y, .s, seen), null },
        },
        '\\' => switch (dir) {
            .n => .{ stepBeam(x, y, .w, seen), null },
            .e => .{ stepBeam(x, y, .s, seen), null },
            .s => .{ stepBeam(x, y, .e, seen), null },
            .w => .{ stepBeam(x, y, .n, seen), null },
        },
        '|' => switch (dir) {
            .n, .s => .{ stepBeam(x, y, dir, seen), null },
            .e, .w => .{ stepBeam(x, y, .n, seen), stepBeam(x, y, .s, seen) },
        },
        '-' => switch (dir) {
            .e, .w => .{ stepBeam(x, y, dir, seen), null },
            .n, .s => .{ stepBeam(x, y, .e, seen), stepBeam(x, y, .w, seen) },
        },
        else => unreachable
    };
}

fn stepBeam(x: usize, y: usize, dir: Dir, seen: [][]const u32) ?Beam
{
    const y_next = switch (dir) {
        .n => std.math.sub(usize, y, 1) catch return null,
        .s => blk: {
            const candidate = y + 1;
            if (candidate > seen.len - 1) return null;
            break :blk candidate;
        },
        else => y
    };
    const x_next = switch (dir) {
        .w => std.math.sub(usize, x, 1) catch return null,
        .e => blk: {
            const candidate = x + 1;
            if (candidate > seen[0].len - 1) return null;
            break :blk candidate;
        },
        else => x
    };

    const visited = seen[y_next][x_next];
    const dir_int = @intFromEnum(dir);
    if (visited & dir_int != 0) return null;

    return .{ .y = y_next, .x = x_next, .dir = dir };
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

    try std.testing.expectEqual(@as(usize, 46), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 51), part2(parsed));
}