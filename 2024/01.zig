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

const INPUT_PATH = "input/01";


const Parsed = struct {
    list1: []usize,
    list2: []usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.list1);
        self.allocator.free(self.list2);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var list1 = List(usize).init(allocator);
    var list2 = List(usize).init(allocator);

    var it = tokenize(u8, raw, " \n");

    while (it.next()) |num_str| {
        list1.append(
            parseInt(usize, num_str, 10) catch unreachable
        ) catch unreachable;
        list2.append(
            parseInt(usize, it.next().?, 10) catch unreachable
        ) catch unreachable;
    }

    return .{
        .list1 = list1.toOwnedSlice() catch unreachable,
        .list2 = list2.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const list1 = parsed.list1;
    const list2 = parsed.list2;
    sort(usize, list1, {}, std.sort.asc(usize));
    sort(usize, list2, {}, std.sort.asc(usize));

    var accum: usize = 0;
    for (list1, list2) |elem1, elem2| accum += util.absdiff(elem1, elem2);

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const list1 = parsed.list1;
    const list2 = parsed.list2;
    sort(usize, list1, {}, std.sort.asc(usize));
    sort(usize, list2, {}, std.sort.asc(usize));

    var accum: usize = 0;
    var idx: usize = 0;
    var counter: usize = 1;
    for (list1, 1..) |elem1, i| {
        if (i < list1.len and elem1 == list1[i]) {
            counter += 1;
            continue;
        }
        while (true) {
            const elem2 = list2[idx];
            if (elem1 == elem2) {
                accum += elem1 * counter;
            } else if (elem1 < elem2) {
                counter = 1;
                break;
            }
            idx += 1;
        }
    }

    return accum;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000000, 1000000);
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

    try std.testing.expectEqual(@as(usize, 11), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 31), part2(parsed));
}