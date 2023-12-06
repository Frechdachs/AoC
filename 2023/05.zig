const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.mem.sort;
const parseInt = std.fmt.parseInt;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/05";


const Parsed = struct {
    seeds: []usize,
    maps: [7][]RangeMapping,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.seeds);
        for (self.maps) |map| {
            self.allocator.free(map);
        }
    }
};

const RangeMapping = struct {
    start_src: usize,
    start_dst: usize,
    len: usize,

    const Self = @This();

    fn getMapping(self: *const Self, n: usize) !usize {
        if (n >= self.start_src) {
            const distance_from_start = n - self.start_src;
            if (distance_from_start < self.len) return self.start_dst + distance_from_start;
            return error.TooHigh;
        }
        return error.TooLow;
    }

    fn intersect(self: *const Self, input: [2]usize) ![3]?[2]usize {
        const start = input[0];
        const len = input[1];

        if (start >= self.start_src + self.len) return error.TooHigh;
        if (start + len <= self.start_src) return error.TooLow;

        var ranges: [3]?[2]usize = .{ null, null, null };

        if (start < self.start_src) {
            ranges[0] = .{
                start,
                self.start_src - start,
            };
        }
        if (start >= self.start_src) {
            ranges[1] = .{
                start,
                @min(len, self.start_src + self.len - start),
            };
        } else {
            ranges[1] = .{
                self.start_src,
                @min(len - (self.start_src - start), self.start_src + self.len - start),
            };
        }
        if (start + len > self.start_src + self.len) {
            ranges[2] = .{
                self.start_src + self.len,
                len - ((self.start_src + self.len) - start)
            };
        }

        return ranges;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var seeds = List(usize).init(allocator);

    var it = split(u8, raw, "\n\n");

    var seeds_str = it.next().?;
    var it_seeds = tokenize(u8, seeds_str, " ");
    _ = it_seeds.next().?;  //seeds:
    while (it_seeds.next()) |num| {
        seeds.append(
            parseInt(usize, num, 10) catch unreachable
        ) catch unreachable;
    }

    var maps: [7][]RangeMapping = undefined;

    var i: usize = 0;

    while (it.next()) |section| : (i += 1) {
        var range_mappings = List(RangeMapping).init(allocator);

        var it_section = tokenize(u8, section, "\n");
        _ = it_section.next().?;  // map name

        while (it_section.next()) |range_str| {
            var it_range = tokenize(u8, range_str, " ");
            const start_dst = parseInt(usize, it_range.next().?, 10) catch unreachable;
            const start_src = parseInt(usize, it_range.next().?, 10) catch unreachable;
            const len = parseInt(usize, it_range.rest(), 10) catch unreachable;

            range_mappings.append(.{
                .start_src = start_src,
                .start_dst = start_dst,
                .len = len,
            }) catch unreachable;
        }

        maps[i] = range_mappings.toOwnedSlice() catch unreachable;
        sort(RangeMapping, maps[i], {}, rangeMappingAsc);
    }

    return .{
        .seeds = seeds.toOwnedSlice() catch unreachable,
        .maps = maps,
        .allocator = allocator,
    };
}

fn rangeMappingAsc(_: void, a: RangeMapping, b: RangeMapping) bool
{
    return a.start_src < b.start_src;
}

fn part1(parsed: Parsed) usize
{
    const seeds = parsed.seeds;

    var min: usize = std.math.maxInt(usize);

    for (seeds) |seed| {
        const value = findMapping(0, seed, parsed.maps);
        min = @min(value, min);
    }

    return min;
}

fn findMapping(current_depth: usize, current_value: usize, maps: [7][]RangeMapping) usize
{
    if (current_depth == 7) return current_value;

    const map = maps[current_depth];


    var left: usize = 0;
    var right: usize = map.len - 1;

    while (left <= right) {
        const pivot = left + (right - left) / 2;
        const candidate = map[pivot];
        const next_value = candidate.getMapping(current_value);

        if (next_value == error.TooHigh) {
            left = pivot + 1;
        } else if (next_value == error.TooLow) {
            if (pivot == 0) break;
            right = pivot - 1;
        } else {
            return findMapping(current_depth + 1, next_value catch unreachable, maps);
        }
    }

    return findMapping(current_depth + 1, current_value, maps);
}

fn part2(parsed: Parsed) usize
{
    const seeds = parsed.seeds;

    var min: usize = std.math.maxInt(usize);

    var i: usize = 0;

    while (i < seeds.len) : (i += 2) {
        const seed_start = seeds[i];
        const seed_count = seeds[i + 1];
        const value = findMinMapping(0, .{ seed_start, seed_count }, parsed.maps);
        min = @min(value, min);
    }

    return min;
}

fn findMinMapping(current_depth: usize, current_value: [2]usize, maps: [7][]RangeMapping) usize
{
    if (current_depth == 7) return current_value[0];

    const map = maps[current_depth];

    var left: usize = 0;
    var right: usize = map.len - 1;

    while (left <= right) {
        const pivot = left + (right - left) / 2;
        const candidate = map[pivot];
        const intersection = candidate.intersect(current_value);

        if (intersection == error.TooHigh) {
            left = pivot + 1;
        } else if (intersection == error.TooLow) {
            if (pivot == 0) break;
            right = pivot - 1;
        } else {
            const ranges = intersection catch unreachable;
            var min: usize = std.math.maxInt(usize);

            if (ranges[0]) |range| {
                min = @min(min, findMinMapping(current_depth, range, maps));
            }
            if (ranges[2]) |range| {
                min = @min(min, findMinMapping(current_depth, range, maps));
            }
            if (ranges[1]) |range| {
                const start = candidate.getMapping(range[0]) catch unreachable;
                min = @min(min, findMinMapping(current_depth + 1, .{ start, range[1] }, maps));
            }

            return min;
        }
    }

    return findMinMapping(current_depth + 1, current_value, maps);
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

    try std.testing.expectEqual(@as(usize, 35), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 46), part2(parsed));
}