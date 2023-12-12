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

const INPUT_PATH = "input/12";


const Parsed = struct {
    rows: [][]const Spring,
    groups: [][]usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.groups) |group| {
            self.allocator.free(group);
        }
        self.allocator.free(self.groups);
        self.allocator.free(self.rows);
    }
};

const Spring = enum(u8) {
    working = '.',
    damaged = '#',
    unknown = '?',
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var rows = List([]const Spring).init(allocator);
    var groups = List([]usize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var it_line = tokenize(u8, line, " ");
        rows.append(@ptrCast(it_line.next().?)) catch unreachable;
        var group = List(usize).init(allocator);
        var it_group = tokenize(u8, it_line.rest(), ",");
        while (it_group.next()) |num| {
            group.append(parseInt(usize, num, 10) catch unreachable) catch unreachable;
        }
        groups.append(group.toOwnedSlice() catch unreachable) catch unreachable;
    }

    return .{
        .rows = rows.toOwnedSlice() catch unreachable,
        .groups = groups.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const rows = parsed.rows;
    const groups = parsed.groups;

    var accum: usize = 0;

    var map = Map([2]usize, usize).init(parsed.allocator);
    defer map.deinit();
    for (rows, groups) |row, group| {
        accum += solve(parsed.allocator, 0, row, group, &map);
        map.clearRetainingCapacity();
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const rows = parsed.rows;
    const groups = parsed.groups;

    var accum: usize = 0;

    var map = Map([2]usize, usize).init(parsed.allocator);
    defer map.deinit();
    for (rows, groups) |row, group| {
        var row_unfolded = unfold(parsed.allocator, row);
        var group_unfolded = unfold(parsed.allocator, group);
        defer parsed.allocator.free(row_unfolded);
        defer parsed.allocator.free(group_unfolded);
        accum += solve(parsed.allocator, 0, row_unfolded, group_unfolded, &map);
        map.clearRetainingCapacity();
    }

    return accum;
}

fn solve(allocator: Allocator, idx: usize, row: []const Spring, group: []usize, map: *Map([2]usize, usize)) usize
{
    if (idx >= row.len) {
        return if (keepGoing(row, group, true) == 2) 1 else 0;
    }

    const keep_going = keepGoing(row, group, false);
    if (keep_going != 2) {
        return keep_going;
    }

    const remaining_count = getRemainingCount(row[0..idx], group);

    if (remaining_count) |count| {
        const seen = map.get(.{ idx, count });
        if (seen) |seen_val| return seen_val;
    }

    switch (row[idx]) {
        .working => {
            const s = solve(allocator, idx + 1, row, group, map);
            if (remaining_count) |count| {
                map.put(.{ idx + 1, count }, s) catch unreachable;
            }
            return s;
        },
        .damaged => {
            const s = solve(allocator, idx + 1, row, group, map);
            return s;
        },
        .unknown => {
            var row_altered1 = allocator.alloc(Spring, row.len) catch unreachable;
            var row_altered2 = allocator.alloc(Spring, row.len) catch unreachable;
            defer allocator.free(row_altered1);
            defer allocator.free(row_altered2);
            @memcpy(row_altered1, row);
            @memcpy(row_altered2, row);
            row_altered1[idx] = .working;
            row_altered2[idx] = .damaged;
            const s1 = solve(allocator, idx, row_altered1, group, map);
            const s2 = solve(allocator, idx, row_altered2, group, map);
            return s1 + s2;
        },
    }

}

fn getRemainingCount(row: []const Spring, group: []usize) ?usize
{
    var consecutive: usize = 0;
    var found_groups: usize = 0;
    var last_working: usize = 0;

    for (row, 0..) |c, idx| {
        switch (c) {
            .working => {
                if (consecutive > 0) {
                    if (found_groups >= group.len) unreachable;
                    if (group[found_groups] != consecutive) unreachable;
                    consecutive = 0;
                    found_groups += 1;
                    last_working = idx;
                }
            },
            .damaged => consecutive += 1,
            else => unreachable,
        }
    }
    if (row.len != last_working + 1) return null;

    return group.len - found_groups;
}

fn keepGoing(row: []const Spring, group: []usize, final: bool) usize
{
    var consecutive: usize = 0;
    var found_groups: usize = 0;

    for (row, 0..) |c, idx| {
        switch (c) {
            .working => {
                if (consecutive > 0) {
                    if (found_groups >= group.len) return 0;
                    if (group[found_groups] != consecutive) return 0;
                    consecutive = 0;
                    found_groups += 1;
                }
            },
            .damaged => {
                consecutive += 1;
                if (found_groups >= group.len or consecutive > group[found_groups]) return 0;
            },
            else => {
                if (found_groups < group.len) {
                    const accum = util.sum(group[found_groups..]) + group[found_groups..].len - 1;
                    if (consecutive > accum) return 0;
                    if (accum - consecutive > row[idx..].len) return 0;
                    if (std.mem.count(Spring, row[idx..], &.{ .damaged }) > accum - consecutive) return 0;
                    return 2;
                } else if (found_groups == group.len) {
                    if (std.mem.indexOfScalar(Spring, row[idx..], .damaged) == null) return 1;
                }
                return 0;
            }
        }
    }
    if (consecutive != 0) {
        if (found_groups >= group.len) return 0;
        if (group[found_groups] != consecutive) return 0;
        consecutive = 0;
        found_groups += 1;
    }

    if (final and found_groups != group.len) return 0;

    return 2;
}

fn unfold(allocator: Allocator, list: anytype) []@TypeOf(list[0])
{
    const T = @TypeOf(list[0]);
    const additional_size = if (T == Spring) 4 else 0;
    var list_unfolded = allocator.alloc(T, list.len * 5 + additional_size) catch unreachable;
    var i: usize = 0;
    while (i < list.len * 5 + additional_size) : (i += list.len + additional_size / 4) {
        @memcpy(list_unfolded[i..i + list.len], list);
        if (T == Spring) {
            if (i + list.len < list_unfolded.len) list_unfolded[i + list.len] = .unknown;
        }
    }
    return list_unfolded;
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

//     try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 1);
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

    try std.testing.expectEqual(@as(usize, 21), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 525152), part2(parsed));
}