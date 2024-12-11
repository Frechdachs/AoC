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

const INPUT_PATH = "input/10";


const Parsed = struct {
    topographic_map: [][]const u8,
    trailheads: [][2]isize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.topographic_map);
        self.allocator.free(self.trailheads);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var topographic_map = List([]const u8).init(allocator);
    var trailheads = List([2]isize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    var y: usize = 0;
    while (it.next()) |line| : (y += 1) {
        topographic_map.append(line) catch unreachable;
        for (line, 0..) |c, x| {
            if (c == '0') trailheads.append(.{ @intCast(x), @intCast(y) }) catch unreachable;
        }
    }

    return .{
        .topographic_map = topographic_map.toOwnedSlice() catch unreachable,
        .trailheads = trailheads.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const topographic_map = parsed.topographic_map;
    const trailheads = parsed.trailheads;

    var accum: usize = 0;
    var peaks = Map([2]isize, void).init(parsed.allocator);
    defer peaks.deinit();
    for (trailheads) |trailhead| {
        peaks.clearRetainingCapacity();
        follow(topographic_map, &peaks, trailhead, '0' - 1);
        accum += peaks.count();
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const topographic_map = parsed.topographic_map;
    const trailheads = parsed.trailheads;

    var accum: usize = 0;
    for (trailheads) |trailhead| {
        follow(topographic_map, &accum, trailhead, '0' - 1);
    }

    return accum;
}

fn follow(topographic_map: [][]const u8, peaks: anytype, pos: [2]isize, height_prev: u8) void
{
    const T = @TypeOf(peaks);

    if (pos[0] < 0 or pos[0] >= topographic_map[0].len or pos[1] < 0 or pos[1] >= topographic_map.len) return;

    const x = pos[0];
    const y = pos[1];
    const height = topographic_map[@intCast(y)][@intCast(x)];
    if (height != height_prev + 1) return;

    if (height == '9') {
        switch (T) {
            *Map([2]isize, void) => peaks.put(pos, {}) catch unreachable,

            *usize => peaks.* += 1,

            else => @compileError("follow: Unsupported type for 'peaks' parameter.")
        }
    }


    follow(topographic_map, peaks, .{ x + 1, y }, height);
    follow(topographic_map, peaks, .{ x, y + 1 }, height);
    follow(topographic_map, peaks, .{ x - 1, y }, height);
    follow(topographic_map, peaks, .{ x, y - 1 }, height);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 10000, 1000);
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

    try std.testing.expectEqual(@as(usize, 36), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 81), part2(parsed));
}