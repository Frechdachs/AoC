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

const INPUT_PATH = "input/02";


const Parsed = struct {
    reports: [][]isize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.reports) |report| {
            self.allocator.free(report);
        }
        self.allocator.free(self.reports);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var reports = List([]isize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var report = List(isize).init(allocator);
        var it_report = tokenize(u8, line, " ");

        while(it_report.next()) |level| {
            report.append(parseInt(isize, level, 10) catch unreachable) catch unreachable;
        }
        reports.append(report.toOwnedSlice() catch unreachable) catch unreachable;
    }

    return .{
        .reports = reports.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const reports = parsed.reports;

    var accum: usize = 0;
    for (reports) |report| {
        if (isSafe(parsed.allocator, report, false)) accum += 1;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const reports = parsed.reports;

    var accum: usize = 0;
    for (reports) |report| {
        if (isSafe(parsed.allocator, report, true)) accum += 1;
    }

    return accum;
}

fn isSafe(allocator: Allocator, report: []isize, comptime allow_almost_bad: bool) bool
{
    assert(report.len > 1);

    var bad = false;
    var diff_prev_maybe: ?isize = null;
    var idx: usize = 0;
    while (idx < report.len - 1) {
        const diff = report[idx] - report[idx + 1];
        if (diff_prev_maybe) |diff_prev| {
            if ((diff ^ diff_prev) < 0) bad = true;
        }
        const diff_abs = util.abs(diff);
        if (bad or diff_abs < 1 or diff_abs > 3 or diff_abs == 0) {
            if (!allow_almost_bad) return false;

            var candidate1 = List(isize).initCapacity(allocator, report.len - 1) catch unreachable;
            var candidate2 = List(isize).initCapacity(allocator, report.len - 1) catch unreachable;
            defer candidate1.deinit();
            defer candidate2.deinit();

            for (report, 0..) |level, i| {
                if (i != idx) candidate1.appendAssumeCapacity(level);
                if (i != idx + 1) candidate2.appendAssumeCapacity(level);
            }
            if (isSafe(allocator, candidate1.items, false)) return true;
            if (isSafe(allocator, candidate2.items, false)) return true;
            // There is a possibility that the very first diff made the wrong choice for the sign of the diff
            if (idx == 1 and isSafe(allocator, report[1..], false)) return true;

            return false;
        }
        diff_prev_maybe = diff;
        idx += 1;
    }

    return true;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 100000, 100000);
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

    try std.testing.expectEqual(@as(usize, 2), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 4), part2(parsed));
}