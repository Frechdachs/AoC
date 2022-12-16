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

const INPUT_PATH = "input/16";
const TEST_INPUT_PATH = "input/16test";


const Parsed = struct {
    valves: std.StringHashMap(Valve),
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        var it = self.valves.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit();
        }
        self.valves.deinit();
    }
};

const Valve = struct {
    rate: usize,
    next: [][]const u8,
    open: bool,
    allocator: Allocator,

    fn deinit(self: *@This()) void {
        self.allocator.free(self.next);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = std.StringHashMap(Valve).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var it_line = tokenize(u8, line, "alve hsfowrt=;und,");
        _ = it_line.next();
        const name = it_line.next().?;
        const rate = parseInt(usize, it_line.next().?, 10) catch unreachable;
        var list = List([]const u8).init(allocator);
        while (it_line.next()) |next| {
            list.append(next) catch unreachable;
        }
        map.put(name, .{ .rate = rate, .next = list.toOwnedSlice(), .open = false, .allocator = allocator }) catch unreachable;
    }

    return .{
        .valves = map,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var best = Map(usize, usize).init(parsed.allocator);
    defer best.deinit();

    return step(&best, parsed.valves, "AA", "", 0, 0, 30);
}

fn step(best: *Map(usize, usize), valves: std.StringHashMap(Valve), current_valve: []const u8, prev: []const u8, increase: usize, accum: usize, n: usize) usize
{
    if (n == 0) return accum;

    var curr_best = best.get(n) orelse 0;
    if (accum > curr_best) best.put(n, accum) catch unreachable;
    if (accum + 20 < curr_best) return 0;

    var max: usize = accum;

    var v = valves.get(current_valve).?;

    if (!v.open and v.rate > 0) {
        var new_valves = valves.clone() catch unreachable;
        defer new_valves.deinit();
        v.open = true;
        new_valves.put(current_valve, v) catch unreachable;
        max = step(best, new_valves, current_valve, "", increase + v.rate, accum + increase, n - 1);
    }

    for (v.next) |next_valve| {
        if (std.mem.eql(u8, next_valve, prev)) {
            continue;
        }
        max = @max(max, step(best, valves, next_valve, current_valve, increase, accum + increase, n - 1));
    }

    return max;
}

fn part2(parsed: Parsed) usize
{
    var best = Map(usize, usize).init(parsed.allocator);
    defer best.deinit();
    return step2(&best, parsed.valves, "AA", "", "AA", "", 0, 0, 26);
}

fn step2(best: *Map(usize, usize), valves: std.StringHashMap(Valve), current_valve1: []const u8, prev1: []const u8, current_valve2: []const u8, prev2: []const u8, increase: usize, accum: usize, n: usize) usize
{
    if (n == 0) return accum;

    var curr_best = best.get(n) orelse 0;
    if (accum > curr_best) best.put(n, accum) catch unreachable;
    if (accum + 40 < curr_best) return 0;

    var max: usize = accum;

    var v1 = valves.get(current_valve1).?;
    var v2 = valves.get(current_valve2).?;

    if (!v1.open and v1.rate > 0) {
        var new_valves = valves.clone() catch unreachable;
        defer new_valves.deinit();
        v1.open = true;
        new_valves.put(current_valve1, v1) catch unreachable;
        for (v2.next) |next_valve2| {
            if (std.mem.eql(u8, next_valve2, prev2)) {
                continue;
            }
            max = @max(max, step2(best, new_valves, current_valve1, "", next_valve2, current_valve2, increase + v1.rate, accum + increase, n - 1));
        }
    }
    v1 = valves.get(current_valve1).?;

    if (!v2.open and v2.rate > 0) {
        var new_valves = valves.clone() catch unreachable;
        defer new_valves.deinit();
        v2.open = true;
        new_valves.put(current_valve2, v2) catch unreachable;
        for (v1.next) |next_valve1| {
            if (std.mem.eql(u8, next_valve1, prev1)) {
                continue;
            }
            max = @max(max, step2(best, new_valves, next_valve1, current_valve1, current_valve2, "", increase + v2.rate, accum + increase, n - 1));
        }
    }
    v2 = valves.get(current_valve2).?;

    for (v1.next) |next_valve1| {
        if (std.mem.eql(u8, next_valve1, prev1)) {
            continue;
        }
        for (v2.next) |next_valve2| {
            if (std.mem.eql(u8, next_valve2, prev2)) {
                continue;
            }
            max = @max(max, step2(best, valves, next_valve1, current_valve1, next_valve2, current_valve2, increase, accum + increase, n - 1));
        }
    }

    if (!v1.open and v1.rate > 0 and !v2.open and v2.rate > 0 and !std.mem.eql(u8, current_valve1, current_valve2)) {
        var new_valves = valves.clone() catch unreachable;
        defer new_valves.deinit();
        v1.open = true;
        v2.open = true;
        new_valves.put(current_valve1, v1) catch unreachable;
        new_valves.put(current_valve2, v2) catch unreachable;
        max = @max(max, step2(best, new_valves, current_valve1, "", current_valve2, "", increase + v1.rate + v2.rate, accum + increase, n - 1));
    }

    return max;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 10);
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
    try std.testing.expect(part1(parsed) == 1651);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 1707);
}