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

const INPUT_PATH = "input/13";


const Parsed = struct {
    patterns: [][][]const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.patterns) |pattern| {
            self.allocator.free(pattern);
        }
        self.allocator.free(self.patterns);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var patterns = List([][]const u8).init(allocator);

    var it = split(u8, raw, "\n\n");

    while(it.next()) |section| {
        var pattern = List([]const u8).init(allocator);
        var it_section = tokenize(u8, section, "\n");

        while (it_section.next()) |line| {
            pattern.append(line) catch unreachable;
        }
        patterns.append(pattern.toOwnedSlice() catch unreachable) catch unreachable;
    }

    return .{
        .patterns = patterns.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const patterns = parsed.patterns;

    var accum: usize = 0;

    for (patterns) |pattern| {
        accum += solve(0, pattern);
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const patterns = parsed.patterns;

    var accum: usize = 0;

    for (patterns) |pattern| {
        accum += solve(1, pattern);
    }

    return accum;
}

fn solve(comptime err_required: comptime_int, pattern: [][]const u8) usize
{
    var i: usize = 0;
    while (i < pattern[0].len - 1) : (i += 1) {
        if (isMirrorVertical(err_required, i, pattern)) {
            return i + 1;
        }
    }

    i = 0;
    while (i < pattern.len - 1) : (i += 1) {
        if (isMirrorHorizontal(err_required, i, pattern)) {
            return (i + 1) * 100;
        }
    }

    unreachable;
}

fn isMirrorVertical(comptime err_required: comptime_int, idx: usize, pattern: [][]const u8) bool
{
    var i: usize = idx + 1;
    var j: usize = idx + 1;
    var err_counter: usize = 0;
    while (i > 0 and j < pattern[0].len) : ({ i -= 1; j += 1; }) {
        for (pattern) |line| {
            if (line[i - 1] != line[j]) {
                err_counter += 1;
                if (err_counter > err_required) return false;
            }
        }
    }

    return err_counter == err_required;
}

fn isMirrorHorizontal(comptime err_required: comptime_int, idx: usize, pattern: [][]const u8) bool
{
    var i: usize = idx + 1;
    var j: usize = idx + 1;
    var err_counter: usize = 0;
    while (i > 0 and j < pattern.len) : ({ i -= 1; j += 1; }) {
        for (0..pattern[0].len) |k| {
            if (pattern[i - 1][k] != pattern[j][k]) {
                err_counter += 1;
                if (err_counter > err_required) return false;
            }
        }
    }

    return err_counter == err_required;
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

    try std.testing.expectEqual(@as(usize, 405), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 400), part2(parsed));
}