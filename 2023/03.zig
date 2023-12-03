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

const INPUT_PATH = "input/03";


const Parsed = struct {
    schematic: [][]const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.schematic);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var schematic = List([]const u8).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        schematic.append(line) catch unreachable;
    }

    return .{
        .schematic = schematic.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const schematic = parsed.schematic;

    var accum: usize = 0;

    for (schematic, 0..) |row, y| {
        var is_digit = false;
        var num_start: usize = 0;
        var num_end: usize = 0;

        for (row, 0..) |elem, x| {
            if (elem >= '0' and elem <= '9') {
                if (!is_digit) {
                    num_start = x;
                    is_digit = true;
                }
            } else {
                if (is_digit) {
                    num_end = x;
                    is_digit = false;
                    if (hasNeighbor(schematic, y, num_start, num_end)) {
                        accum += parseNumber(row, num_start, num_end);
                    }
                }
            }
        }
        if (is_digit) {
            num_end = row.len;
            is_digit = false;
            if (hasNeighbor(schematic, y, num_start, num_end)) {
                accum += parseNumber(row, num_start, num_end);
            }
        }
    }

    return accum;
}

fn hasNeighbor(schematic: [][]const u8, y_num: usize, num_start: usize, num_end: usize) bool
{
    const x_start = num_start -| 1;
    const x_end = if (num_end < schematic[y_num].len) num_end + 1 else num_end;
    const y_start = y_num -| 1;
    const y_end = if (y_num < schematic.len - 1) y_num + 2 else y_num + 1;

    for (y_start..y_end) |y| {
        for (x_start..x_end) |x| {
            if (x >= num_start and x < num_end and y == y_num) continue;
            if (schematic[y][x] != '.') return true;
        }
    }

    return false;
}

fn parseNumber(row: []const u8, num_start: usize, num_end: usize) usize
{
    var accum: usize = 0;

    for (num_start..num_end) |x| {
        accum = accum * 10 + (row[x] - '0');
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const schematic = parsed.schematic;

    var accum: usize = 0;

    for (schematic, 0..) |row, y| {
        gear: for (row, 0..) |c, x| {
            if (c == '*') {
                const x_start = x -| 1;
                const x_end = if (x < row.len - 1) x + 2 else x + 1;
                const y_start = y -| 1;
                const y_end = if (y < schematic.len - 1) y + 2 else y + 1;

                var num_count: usize = 0;
                var product: usize = 1;

                for (y_start..y_end) |y2| {
                    var is_digit = false;
                    var num_start: usize = 0;

                    for (x_start..x_end) |x2| {
                        const neighbor = schematic[y2][x2];

                        if (neighbor >= '0' and neighbor <= '9') {
                            if (!is_digit) {
                                is_digit = true;
                                num_start = x2;
                                num_count += 1;
                                if (num_count > 2) continue :gear;
                            }
                        } else {
                            if (is_digit) {
                                is_digit = false;
                                product *= parseNumber2(schematic[y2], num_start);
                            }
                        }
                    }
                    if (is_digit) {
                        is_digit = false;
                        product *= parseNumber2(schematic[y2], num_start);
                    }
                }
                if (num_count == 2) {
                    accum += product;
                }
            }
        }
    }

    return accum;
}

fn parseNumber2(row: []const u8, num_start2: usize) usize
{
    var accum: usize = 0;
    var num_start = num_start2;

    while (num_start > 0 and row[num_start - 1] >= '0' and row[num_start - 1] <= '9') num_start -= 1;

    for (num_start..row.len) |x| {
        if (row[x] < '0' or row[x] > '9') break;
        accum = accum * 10 + (row[x] - '0');
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

    try std.testing.expectEqual(@as(usize, 4361), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 467835), part2(parsed));
}