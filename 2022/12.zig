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

const INPUT_PATH = "input/12";
const TEST_INPUT_PATH = "input/12test";


const Parsed = struct {
    starting_points: [][2]isize,
    end: [2]isize,
    map: util.Grid(u8),
    allocator: Allocator,

    fn deinit(self: *@This()) void {
        self.allocator.free(self.starting_points);
        self.map.deinit();
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = util.Grid(u8).init(allocator);
    var starting_points = List([2]isize).init(allocator);

    var start: [2]isize = undefined;
    var end: [2]isize = undefined;
    var it = tokenize(u8, raw, "\n");
    var i: isize = 0;
    while (it.next()) |line| : (i += 1) {
        for (line) |c, j| {
            const point = [2]isize{ i, @intCast(isize, j) };
            var height = c;
            if (height == 'a') starting_points.append(point) catch unreachable;
            if (c == 'S') {
                start = point;
                height = 'a';
            } else if (c == 'E') {
                end = point;
                height = 'z';
            }
            map.put(point, height) catch unreachable;
        }
    }
    starting_points.append(start) catch unreachable;  // Put part 1 starting point at the end of the list

    return .{
        .starting_points = starting_points.toOwnedSlice(),
        .end = end,
        .map = map,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const start = parsed.starting_points[parsed.starting_points.len - 1];

    return findFewestSteps(&parsed.map, start, parsed.end);
}

fn part2(parsed: Parsed) usize
{
    var min: usize = std.math.maxInt(usize);

    for (parsed.starting_points) |start| {
        min = @min(min, findFewestSteps(&parsed.map, start, parsed.end));
    }

    return min;
}

/// Terrible hack to declare a tuple type
fn Tuple(comptime T: type, comptime U: type) type
{
    return @TypeOf(.{ as(T, 0), as(U, .{ 0, 0 }) });
}

/// Hack to make the value not comptime-known
fn as(comptime T: type, a: anytype) T
{
    return @as(T, a);
}

/// Based on Dijkstra
fn findFewestSteps(map: *const util.Grid(u8), start: [2]isize, end: [2]isize) usize
{
    const allocator = std.heap.c_allocator;
    var visited = Map([2]isize, void).init(allocator);
    defer visited.deinit();
    var steps = util.Grid(usize).init(allocator);
    defer steps.deinit();
    var queue = std.PriorityQueue(Tuple(usize, [2]isize), void, lessThanOrder).init(allocator, {});
    defer queue.deinit();
    steps.put(start, 0) catch unreachable;
    queue.add(.{ 0, start }) catch unreachable;

    while (queue.count() > 0) {
        const curr = queue.remove()[1];
        visited.put(curr, {}) catch unreachable;
        const curr_height = map.get(curr).?;
        const curr_steps = steps.get(curr).?;
        const y = curr[0];
        const x = curr[1];

        if (y == end[0] and x == end[1]) return curr_steps;

        const neighbors = [4][2]isize{
            .{  y + 1, x },
            .{  y - 1, x },
            .{  y, x + 1 },
            .{  y, x - 1 },
        };
        for (neighbors) |neighbor| {
            if (visited.contains(neighbor)) continue;
            if (map.get(neighbor)) |next_height| {
                if (next_height > curr_height and next_height - curr_height != 1) continue;
                const old_steps = steps.get(neighbor) orelse std.math.maxInt(usize);

                const new_steps = curr_steps + 1;
                if (new_steps < old_steps) {
                    steps.put(neighbor, new_steps) catch unreachable;
                    if (old_steps == std.math.maxInt(usize)) {
                        queue.add(.{ new_steps, neighbor }) catch unreachable;
                    }
                    else {
                        queue.update(.{ old_steps, neighbor }, .{ new_steps, neighbor }) catch unreachable;
                    }
                }
            }
        }
    }

    return std.math.maxInt(usize);
}

fn lessThanOrder(context: void, a: Tuple(usize, [2]isize), b: Tuple(usize, [2]isize)) std.math.Order
{
    _ = context;

    if (a[0] == b[0]) {
        if (a[1][0] == b[1][0]) {
            return std.math.order(a[1][1], b[1][1]);
        } else {
            return std.math.order(a[1][0], b[1][0]);
        }
    }

    return std.math.order(a[0], b[0]);
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
    while (i < 1000 + warmup) : (i += 1) {
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
    while (i < 100 + warmup) : (i += 1) {
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
    try std.testing.expect(part1(parsed) == 31);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 29);
}