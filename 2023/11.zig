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

const INPUT_PATH = "input/11";


const Parsed = struct {
    galaxies: [][2]usize,
    empty_y: []usize,
    empty_x: []usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.empty_y);
        self.allocator.free(self.empty_x);
        self.allocator.free(self.galaxies);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var galaxies = List([2]usize).init(allocator);

    var it = tokenize(u8, raw, "\n");
    const first_line = it.peek().?;
    const n = first_line.len;
    var empty_y = allocator.alloc(usize, n) catch unreachable;
    var empty_x = allocator.alloc(usize, n) catch unreachable;
    @memset(empty_y, 1);
    @memset(empty_x, 1);

    var y: usize = 0;
    while (it.next()) |line| : (y += 1) {
        for (line, 0..) |c, x| {
            if (c == '#') {
                empty_y[y] = 0;
                empty_x[x] = 0;
                galaxies.append(.{ y, x }) catch unreachable;
            }
        }
    }

    for (1..n) |i| {
        empty_y[i] += empty_y[i - 1];
        empty_x[i] += empty_x[i - 1];
    }

    return .{
        .galaxies = galaxies.toOwnedSlice() catch unreachable,
        .empty_y = empty_y,
        .empty_x = empty_x,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const allocator = parsed.allocator;
    const galaxies = parsed.galaxies;
    const empty_y = parsed.empty_y;
    const empty_x = parsed.empty_x;

    return solve(1, allocator, galaxies, empty_y, empty_x);
}

fn part2(parsed: Parsed) usize
{
    const allocator = parsed.allocator;
    const galaxies = parsed.galaxies;
    const empty_y = parsed.empty_y;
    const empty_x = parsed.empty_x;

    return solve(1_000_000 - 1, allocator, galaxies, empty_y, empty_x);
}

fn solve(comptime n: usize, allocator: Allocator, galaxies: [][2]usize, empty_y: []usize, empty_x: []usize) usize
{
    var accum: usize = 0;

    var galaxies_adjusted = allocator.alloc(@TypeOf(galaxies[0]), galaxies.len) catch unreachable;
    defer allocator.free(galaxies_adjusted);
    @memcpy(galaxies_adjusted, galaxies);
    for (galaxies_adjusted) |*g| {
        g.* = .{ g[0] + empty_y[g[0]] * n, g[1] + empty_x[g[1]] * n };
    }

    for (0..galaxies_adjusted.len - 1) |i| {
        for (i..galaxies_adjusted.len) |j| {
            const g1 = galaxies_adjusted[i];
            const g2 = galaxies_adjusted[j];

            accum += util.absdiff(g1[0], g2[0]) + util.absdiff(g1[1], g2[1]);
        }
    }

    return accum;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 10000);
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

    try std.testing.expectEqual(@as(usize, 374), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 82000210), part2(parsed));
}