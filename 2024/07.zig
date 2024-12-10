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

const INPUT_PATH = "input/07";


const Parsed = struct {
    equations: []Equation,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.equations) |equation| {
            self.allocator.free(equation.nums);
        }
        self.allocator.free(self.equations);
    }
};

const Equation = struct {
    test_value: usize,
    nums: []usize,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var equations = List(Equation).init(allocator);
    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var it_line = tokenize(u8, line, " :");
        const test_value = parseInt(usize, it_line.next().?, 10) catch unreachable;
        var nums = List(usize).init(allocator);

        while (it_line.next()) |num_str| {
            nums.append(parseInt(usize, num_str, 10) catch unreachable) catch unreachable;
        }
        equations.append(.{
            .test_value = test_value,
            .nums = nums.toOwnedSlice() catch unreachable,
        }) catch unreachable;
    }

    return .{
        .equations = equations.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const equations = parsed.equations;

    var accum: usize = 0;
    for (equations) |equation| {
        if (check(equation.test_value, equation.nums[1..], equation.nums[0], false)) accum += equation.test_value;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const equations = parsed.equations;

    var accum: usize = 0;
    for (equations) |equation| {
        if (check(equation.test_value, equation.nums[1..], equation.nums[0], true)) accum += equation.test_value;
    }

    return accum;
}

fn check(test_value: usize, nums: []usize, accum: usize, comptime concat: bool) bool
{
    if (nums.len == 0) {
        if (test_value == accum) return true;

        return false;
    }

    return check(test_value, nums[1..], accum + nums[0], concat) or check(test_value, nums[1..], accum * nums[0], concat) or blk: {
        if (!concat) break :blk false;

        var temp = nums[0] / 10;
        var shift: usize = 10;
        while (temp != 0) : (shift *= 10) temp /= 10;

        break :blk check(test_value, nums[1..], accum * shift + nums[0], concat);
    };
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 1000);
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

    try std.testing.expectEqual(@as(usize, 3749), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 11387), part2(parsed));
}