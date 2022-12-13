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

const INPUT_PATH = "input/13";
const TEST_INPUT_PATH = "input/13test";


const Parsed = struct {
    packets: [][]const u8,
    allocator: Allocator,

    fn deinit(self: *@This()) void {
        self.allocator.free(self.packets);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var packets = List([]const u8).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        packets.append(line) catch unreachable;
    }

    return .{
        .packets = packets.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var accum: usize = 0;
    var i: usize = 0;
    while (i + 1 < parsed.packets.len) : (i += 2) {
        const p1 = parsed.packets[i];
        const p2 = parsed.packets[i + 1];
        var idx1: usize = 0;
        var idx2: usize = 0;
        const check = comparePackets(p1, p2, &idx1, &idx2);
        if (check == .lt) accum += i / 2 + 1;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const divider1 = "[[2]]";
    const divider2 = "[[6]]";

    var accum1: usize = 1;
    var accum2: usize = 1;
    for (parsed.packets) |p| {
        var idx1: usize = 0;
        var idx2: usize = 0;

        if (comparePackets(p, divider1, &idx1, &idx2) == .lt) {
            accum1 += 1;
        } else {
            idx1 = 0;
            idx2 = 0;
            if (comparePackets(p, divider2, &idx1, &idx2) == .lt)
                accum2 += 1;
        }
    }

    return accum1 * (accum1 + accum2);
}

fn comparePackets(p1: []const u8, p2: []const u8, idx1: *usize, idx2: *usize) std.math.Order
{
    var c1 = p1[idx1.*];
    var c2 = p2[idx2.*];

    const p1_is_number = c1 != '[';
    const p2_is_number = c2 != '[';

    if (p1_is_number and p2_is_number) {
        const n1 = getNumber(p1, idx1);
        const n2 = getNumber(p2, idx2);
        return std.math.order(n1, n2);

    } else if (p2_is_number) {
        idx1.* += 1;
        const n1 = unpackOne(p1, idx1);
        const n2 = getNumber(p2, idx2);
        return if (n1 < n2) .lt else .gt;

    } else if (p1_is_number) {
        idx2.* += 1;
        const n1 = getNumber(p1, idx1);
        const n2 = unpackOne(p2, idx2);
        return if (n1 <= n2) .lt else .gt;

    } else {
        idx1.* += 1;
        idx2.* += 1;

        var check = std.math.Order.eq;
        while (check == .eq) {
            c1 = p1[idx1.*];
            c2 = p2[idx2.*];
            const p1_is_end = c1 == ']';
            const p2_is_end = c2 == ']';
            if (p1_is_end or c1 == ',') idx1.* += 1;
            if (p2_is_end or c2 == ',') idx2.* += 1;

            if (p1_is_end and p2_is_end) return .eq;
            if (p1_is_end) return .lt;
            if (p2_is_end) return .gt;

            check = comparePackets(p1, p2, idx1, idx2);
        }

        return check;
    }
}

fn getNumber(p: []const u8, idx: *usize) i8
{
    var i: usize = idx.* + 1;
    while (p[i] >= '0' and p[i] <= '9') i += 1;
    const num = parseInt(i8, p[idx.*..i], 10) catch unreachable;
    idx.* = i;

    return num;
}

fn unpackOne(p: []const u8, idx: *usize) i8
{
    var c = p[idx.*];
    while (c == '[') {
        idx.* += 1;
        c = p[idx.*];
    }
    if (c == ']') return -1;

    return getNumber(p, idx);
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

    try benchmark();
}


//
// Benchmarks and tests
//
fn benchmark() !void
{
    const allocator = std.heap.c_allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var parsed: Parsed = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 10000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p1 = part1(parsed);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p2 = part2(parsed);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part1(parsed) == 13);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 140);
}