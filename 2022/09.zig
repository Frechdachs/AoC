const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const splitBackwards = std.mem.splitBackwards;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const parser = @import("parser.zig");
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const INPUT_PATH = "input/09";
const TEST_INPUT_PATH = "input/09test";


const Parsed = [][2]usize;

const Rope = struct {
    knots: [][2]isize,
    visited: util.Grid(void),
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, n: usize) Self {
        assert(n > 1);
        var knots = List([2]isize).init(allocator);
        var visited = util.Grid(void).init(allocator);
        const knot = .{ 0, 0 };

        var i: usize = 0;
        while (i < n) : (i += 1) {
            knots.append(knot) catch unreachable;
        }
        visited.put(knot, {}) catch unreachable;

        return .{
            .knots = knots.toOwnedSlice(),
            .visited = visited,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.knots);
        self.visited.deinit();
    }

    fn simulate(self: *Self, movement: [2]usize) void {
        const dir = movement[0];
        var steps = movement[1];

        const add_table = [_][2]isize{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

        const add = switch (dir) {
            'D' => add_table[0],
            'U' => add_table[1],
            'R' => add_table[2],
            'L' => add_table[3],
            else => unreachable,
        };

        while (steps > 0) : (steps -= 1) {
            self.knots[0][0] += add[0];
            self.knots[0][1] += add[1];

            for (self.knots[1..]) |*knot, i| {
                const diff = .{
                    self.knots[i][0] - knot[0],
                    self.knots[i][1] - knot[1],
                };

                if (diff[0] >= 2 or diff[0] <= -2) {
                    knot[0] += @divTrunc(diff[0], 2);
                    if (diff[1] == 1 or diff[1] == -1) {
                        knot[1] += diff[1];
                    }
                }
                if (diff[1] >= 2 or diff[1] <= -2) {
                    knot[1] += @divTrunc(diff[1], 2);
                    if (diff[0] == 1 or diff[0] == -1) {
                        knot[0] += diff[0];
                    }
                }

                if (i + 2 == self.knots.len) {
                    self.visited.put(knot.*, {}) catch unreachable;
                }
            }
        }
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var parsed = List([2]usize).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        parsed.append(.{
            line[0],
            parseInt(usize, line[2..], 10) catch unreachable,
        }) catch unreachable;
    }

    return parsed.toOwnedSlice();
}

fn part1(parsed: Parsed) usize
{
    const allocator = std.heap.c_allocator;
    var rope = Rope.init(allocator, 2);
    defer rope.deinit();

    for (parsed) |movement| {
        rope.simulate(movement);
    }

    return rope.visited.count();
}

fn part2(parsed: Parsed) usize
{
    const allocator = std.heap.c_allocator;
    var rope = Rope.init(allocator, 10);
    defer rope.deinit();

    for (parsed) |movement| {
        rope.simulate(movement);
    }

    return rope.visited.count();
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
    while (i < 1000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
        if (i >= warmup) timer.reset();
        p1 = part1(parsed);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
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
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(part1(parsed) == 13);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH ++ "2", 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(part2(parsed) == 36);
}