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

const INPUT_PATH = "input/01";
const TEST_INPUT_PATH = "input/01test";


const Parsed = struct {
    document: [][]const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.document);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var document = List([]const u8).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        document.append(line) catch unreachable;
    }

    return .{
        .document = document.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const document = parsed.document;

    var accum: usize = 0;
    for (document) |line| {
        var it = tokenize(u8, line, "abcdefghijklmnopqrstuvwxyz");
        const d1_str = it.next().?;
        const d1 = d1_str[0] - '0';
        var d2 = d1_str[d1_str.len - 1] - '0';
        while (it.next()) |d| {
            d2 = d[d.len - 1] - '0';
        }
        accum += @as(usize, d1) * 10 + d2;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const document = parsed.document;

    var accum: usize = 0;
    for (document) |line| {
        var d1: ?u8 = null;
        var d2: u8 = 0;
        for (line, 0..) |c, i| {
            if (c >= '0' and c <= '9') {
                if (d1 == null) d1 = c - '0';
                d2 = c - '0';
            } else {
                const maybe_d: ?u8 = get_written_digit(line, i);
                if (maybe_d) |d| {
                    if (d1 == null) d1 = d;
                    d2 = d;
                }
            }
        }
        accum += @as(usize, d1.?) * 10 + d2;
    }

    return accum;
}

fn get_written_digit(line: []const u8, i: usize) ?u8
{
    const candidate = line[i..];
    const remaining_chars = line.len - i;

    if (remaining_chars < 3) return null;

    if (std.mem.eql(u8, candidate[0..3], "one")) return 1;
    if (std.mem.eql(u8, candidate[0..3], "two")) return 2;
    if (std.mem.eql(u8, candidate[0..3], "six")) return 6;

    if (remaining_chars < 4) return null;

    if (std.mem.eql(u8, candidate[0..4], "four")) return 4;
    if (std.mem.eql(u8, candidate[0..4], "five")) return 5;
    if (std.mem.eql(u8, candidate[0..4], "nine")) return 9;

    if (remaining_chars < 5) return null;

    if (std.mem.eql(u8, candidate[0..5], "three")) return 3;
    if (std.mem.eql(u8, candidate[0..5], "seven")) return 7;
    if (std.mem.eql(u8, candidate[0..5], "eight")) return 8;

    return null;
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
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part1(parsed) == 142);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH ++ "2", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 281);
}