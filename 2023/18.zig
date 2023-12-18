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

const INPUT_PATH = "input/18";


const Parsed = struct {
    dig_plan_p1: []Instruction,
    dig_plan_p2: []Instruction,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.dig_plan_p1);
        self.allocator.free(self.dig_plan_p2);
    }
};

const Instruction = struct {
    dir: Dir,
    count: usize,
};

const Dir = enum(u8) {
    n = 'U',
    e = 'R',
    s = 'D',
    w = 'L',
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var dig_plan_p1 = List(Instruction).init(allocator);
    var dig_plan_p2 = List(Instruction).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        const dir_p1: Dir = @enumFromInt(line[0]);
        const idx = std.mem.indexOf(u8, line[2..], " ").?;
        const count_p1 = parseInt(usize, line[2..2 + idx], 10) catch unreachable;
        const count_p2 = parseInt(usize, line[idx + 5..idx + 10], 16) catch unreachable;
        const dir_p2: Dir = switch (line[idx + 10]) {
            '0' => .e,
            '1' => .s,
            '2' => .w,
            '3' => .n,
            else => unreachable
        };

        dig_plan_p1.append(.{
            .dir = dir_p1,
            .count = count_p1,
        }) catch unreachable;
        dig_plan_p2.append(.{
            .dir = dir_p2,
            .count = count_p2,
        }) catch unreachable;
    }

    return .{
        .dig_plan_p1 = dig_plan_p1.toOwnedSlice() catch unreachable,
        .dig_plan_p2 = dig_plan_p2.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const dig_plan = parsed.dig_plan_p1;

    return calculateArea(dig_plan);
}

fn part2(parsed: Parsed) usize
{
    const dig_plan = parsed.dig_plan_p2;

    return calculateArea(dig_plan);
}

fn calculateArea(dig_plan: []Instruction) usize
{
    var curr_y: isize = 0;
    var curr_x: isize = 0;

    var p0: [2]isize = .{ curr_y, curr_x };
    var p1 = p0;
    var p2 = p1;

    var area_twice: isize = 0;
    var border_count: usize = 0;

    for (dig_plan) |instruction| {
        const dir = instruction.dir;
        const count = instruction.count;
        const count_signed: isize = @intCast(count);

        switch (dir) {
            .n => curr_y -= count_signed,
            .e => curr_x += count_signed,
            .s => curr_y += count_signed,
            .w => curr_x -= count_signed,
        }

        p0 = p1;
        p1 = p2;
        p2 = .{ curr_y, curr_x };

        // Several equivalent formulas for the area of a simple polygon
        area_twice += p1[1] * (p2[0] - p0[0]);
        //area_twice += p1[0] * (p0[1] - p2[1]);
        //area_twice += p1[1] * p2[0] - p2[1] * p1[0];
        //area_twice += (p1[0] + p2[0]) * (p1[1] - p2[1]);
        border_count += count;
    }

    const area_twice_abs: usize = @intCast(util.abs(area_twice));

    return (area_twice_abs + border_count + 2) / 2;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 100000, 100000);
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

    try std.testing.expectEqual(@as(usize, 62), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 952408144115), part2(parsed));
}