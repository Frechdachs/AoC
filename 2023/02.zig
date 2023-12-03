const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/02";


const Parsed = struct {
    games: []Set,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.games);
    }
};

const Set = @Vector(3, usize);

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var games = List(Set).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var max_counts = Set{ 0, 0, 0 };
        var it_line = tokenize(u8, line, ":;");
        _ = it_line.next(); // Game 1[:]

        while (it_line.next()) |set_str| {
            var set_counts: Set = Set{ 0, 0, 0 };
            var it_set = tokenize(u8, set_str, " ,renlu");

            while (it_set.next()) |count_str| {
                const count = parseInt(usize, count_str, 10) catch unreachable;
                const color = it_set.next().?[0];

                switch (color) {
                    // [re]d
                    'd' => set_counts[0] = count,
                    // g[reen]
                    'g' => set_counts[1] = count,
                    // b[lue]
                    'b' => set_counts[2] = count,

                    else => unreachable
                }
            }
            max_counts = @max(max_counts, set_counts);
        }
        games.append(max_counts) catch unreachable;
    }

    return .{
        .games = games.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const games = parsed.games;

    const limit = Set{ 12, 13, 14 };
    var accum: usize = 0;

    for (games, 1..) |max_counts, i| {
        if (!@reduce(.Or, max_counts > limit)) {
            accum += i;
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const games = parsed.games;

    var accum: usize = 0;

    for (games) |max_counts| {
        accum += @reduce(.Mul, max_counts);
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

    try std.testing.expectEqual(@as(usize, 8), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2286), part2(parsed));
}