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

const INPUT_PATH = "input/09";


const Parsed = struct {
    histories: [][]isize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.histories) |history| {
            self.allocator.free(history);
        }
        self.allocator.free(self.histories);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var histories = List([]isize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var nums = List(isize).init(allocator);
        var it_line = tokenize(u8, line, " ");

        while (it_line.next()) |num| {
            nums.append(parseInt(isize, num, 10) catch unreachable) catch unreachable;
        }

        histories.append(nums.toOwnedSlice() catch unreachable) catch unreachable;
    }

    return .{
        .histories = histories.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const histories = parsed.histories;

    var accum: isize = 0;

    for (histories) |history| {
        accum += extrapolate(false, parsed.allocator, history);
    }

    return @intCast(accum);
}

fn part2(parsed: Parsed) usize
{
    const histories = parsed.histories;

    var accum: isize = 0;

    for (histories) |history| {
        accum += extrapolate(true, parsed.allocator, history);
    }

    return @intCast(accum);
}

fn extrapolate(comptime backwards: bool, allocator: Allocator, history: []isize) isize
{
    for (history[1..]) |num| {
        if (num != history[0]) break;
    } else {
        return history[0];
    }

    var diff = allocator.alloc(isize, history.len - 1) catch unreachable;
    defer allocator.free(diff);

    var i: usize = 0;
    while (i < history.len - 1) : (i += 1) {
        diff[i] = history[i + 1] - history[i];
    }

    if (backwards){
        return history[0] - extrapolate(backwards, allocator, diff);
    } else {
        return history[history.len - 1] + extrapolate(backwards, allocator, diff);
    }
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

    try std.testing.expectEqual(@as(usize, 114), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), part2(parsed));
}