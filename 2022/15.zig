const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const splitBackwards = std.mem.splitBackwards;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const INPUT_PATH = "input/15";
const TEST_INPUT_PATH = "input/15test";


const Parsed = struct {
    scanners: []Scanner,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.scanners);
    }
};

const Scanner = struct {
    x: isize,
    y: isize,
    range: isize,
    beacon_x: isize,
    beacon_y: isize,

    fn sees(self: *const @This(), x: isize, y: isize) bool {
        const diff = util.absdiff(x, self.x) + util.absdiff(y, self.y);

        return diff <= self.range;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var scanners = List(Scanner).init(allocator);
    var it = tokenize(u8, raw, "Sensor atx=y:clbi,\n");
    while (it.next()) |sx_str| {
        const sy_str = it.next().?;
        const bx_str = it.next().?;
        const by_str = it.next().?;
        const sx = parseInt(isize, sx_str, 10) catch unreachable;
        const sy = parseInt(isize, sy_str, 10) catch unreachable;
        const bx = parseInt(isize, bx_str, 10) catch unreachable;
        const by = parseInt(isize, by_str, 10) catch unreachable;

        const range = util.absdiff(sx, bx) + util.absdiff(sy, by);

        const scanner = .{
            .x = sx,
            .y = sy,
            .range = range,
            .beacon_x = bx,
            .beacon_y = by,
        };

        scanners.append(scanner) catch unreachable;
    }

    return .{
        .scanners = scanners.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    return solvePart1(2_000_000, parsed);
}

fn part2(parsed: Parsed) usize
{
    return solvePart2(4_000_000, parsed);
}

fn solvePart1(comptime y_pos: isize, parsed: Parsed) usize
{
    const scanners = parsed.scanners;
    var beacons = Map([2]isize, void).init(parsed.allocator);
    defer beacons.deinit();
    var ranges = List(struct { l: isize, r: isize }).init(parsed.allocator);
    defer ranges.deinit();

    outer: for (scanners) |scanner| {
        const start = scanner.x - scanner.range + util.absdiff(scanner.y, y_pos);
        const end = scanner.x + scanner.range - util.absdiff(scanner.y, y_pos);
        if (scanner.beacon_y == y_pos) {
            beacons.put(.{ scanner.beacon_x, scanner.beacon_y }, {}) catch unreachable;
        }

        // This loop could be simplyfied if I'd just use a temporary list
        // but why should I if I don't have to :)
        var i: usize = 0;
        while (i < ranges.items.len) {
            const range = &ranges.items[i];
            const l = range.l;
            const r = range.r;
            if (start >= l and end <= r) {
                continue :outer;
            } else if (start <= l and end >= r) {
                _ = ranges.swapRemove(i);
                // Don't increment i here because we need to check
                // the new element at this position
                continue;
            } else if (start <= l and end >= l) {
                range.l = end + 1;
            } else if (start <= r and end >= r) {
                range.r = start - 1;
            }
            i += 1;
        }
        ranges.append(.{ .l = start, .r = end }) catch unreachable;
    }

    var accum: usize = 0;
    for (ranges.items) |range| {
        accum += @intCast(usize, range.r - range.l + 1);
    }

    return accum - beacons.count();
}

fn solvePart2(comptime limit: isize, parsed: Parsed) usize
{
    const scanners = parsed.scanners;

    var result: isize = 0;
    var x: isize = 0;
    outer: while (x <= limit) : (x += 1) {
        var y: isize = 0;
        inner: while (y <= limit) : (y += 1) {
            for (scanners) |scanner| {
                if (scanner.sees(x, y)) {
                    y = scanner.range + scanner.y - util.absdiff(x, scanner.x);
                    continue :inner;
                }
            }
            result = 4_000_000 * x + y;
            break :outer;
        }
    }

    return @intCast(usize, result);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 10);
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
    try std.testing.expect(solvePart1(10, parsed) == 26);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(solvePart2(20, parsed) == 56000011);
}