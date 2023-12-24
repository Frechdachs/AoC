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

const INPUT_PATH = "input/23";


const Parsed = struct {
    map: [][]const Tile,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.map);
    }
};

const Tile = enum(u8) {
    path = '.',
    forest = '#',
    up = '^',
    right = '>',
    down = 'v',
    left = '<',
};

const Node = struct {
    edges: List(Edge),
};

const Edge = struct {
    destination: [2]usize,
    weight: usize,
    traversable: bool,
};

const Step = struct {
    pos: [2]usize,
    dir: u2,
};

const DIRS_ALL = [_]u2{ 0, 1, 2, 3 };

const DIR_SLOPE_MAP = [_]Tile{ .up, .right, .down, .left };

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    const line_length = std.mem.indexOf(u8, raw, "\n").?;
    var map = List([]const Tile).initCapacity(allocator, line_length) catch unreachable;

    var i: usize = 0;
    while (i < raw.len) : (i += line_length + 1) {
        const line = raw[i..i + line_length];
        map.appendAssumeCapacity(@ptrCast(line));
    }

    return .{
        .map = map.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    return solve(true, parsed.allocator, parsed.map);
}

fn part2(parsed: Parsed) usize
{
    return solve(false, parsed.allocator, parsed.map);
}

fn solve(comptime directed: bool, allocator: Allocator, map: [][]const Tile) usize {
    var seen = Map([2]usize, void).init(allocator);
    defer seen.deinit();
    var nodes = Map([2]usize, Node).init(allocator);
    defer nodes.deinit();
    defer {
        var it_entry = nodes.iterator();
        while (it_entry.next()) |entry| {
            entry.value_ptr.edges.deinit();
        }
    }

    const start: Node = .{ .edges = List(Edge).init(allocator) };
    nodes.put(.{ 0, 1 }, start) catch unreachable;

    constructGraph(allocator, 0, .{ .pos = .{ 0, 1 }, .dir = 2 }, .{ 0, 1 }, map, &seen, &nodes);

    return getLongestPath(directed, allocator, .{ 0, 1 }, .{ map.len - 1, map[0].len - 2 }, &nodes);
}

fn constructGraph(allocator: Allocator, weight: usize, step: Step, from: [2]usize, map: [][]const Tile, seen: *Map([2]usize, void), nodes: *Map([2]usize, Node)) void
{
    if (step.pos[0] == map.len - 1 and step.pos[1] == map[0].len - 2) {
        addEdges(allocator, step.pos, from, weight, nodes);
        return;
    }

    const neighbors_result = getNeighbors(step, map, seen);
    const is_node = neighbors_result[0];
    const neighbors = neighbors_result[1];
    if (is_node) {
        addEdges(allocator, step.pos, from, weight, nodes);
        for (neighbors.slice()) |neighbor| {
            constructGraph(allocator, 1, neighbor, step.pos, map, seen, nodes);
        }
    } else if (neighbors.slice().len > 0) {
        assert(neighbors.slice().len <= 1);
        constructGraph(allocator, weight + 1, neighbors.slice()[0], from, map, seen, nodes);
    }
}

fn addEdges(allocator: Allocator, to: [2]usize, from: [2]usize, weight: usize, nodes: *Map([2]usize, Node)) void
{
    const from_edges = &nodes.getPtr(from).?.edges;
    from_edges.append(.{
        .destination = to,
        .weight = weight,
        .traversable = true,
    }) catch unreachable;
    const to_edge = Edge{
        .destination = from,
        .weight = weight,
        .traversable = false,
    };
    const result = nodes.getOrPut(to) catch unreachable;
    const to_edges = &result.value_ptr.edges;
    if (!result.found_existing) {
        to_edges.* = List(Edge).init(allocator);
    }
    to_edges.append(to_edge) catch unreachable;
}

fn getNeighbors(step: Step, map: [][]const Tile, seen: *Map([2]usize, void)) std.meta.Tuple(&.{ bool, std.BoundedArray(Step, 4) })
{
    const y = step.pos[0];
    const x = step.pos[1];
    const dir_last = step.dir;
    var neighbors = std.BoundedArray(Step, 4).init(0) catch unreachable;
    var neighbors_counter: usize = 0;

    for (DIRS_ALL) |i| {
        var neighbor: [2]usize = undefined;
        switch (i) {
            0 => {
                neighbor = .{ std.math.sub(usize, y, 1) catch continue, x };
            },
            1 => {
                neighbor = .{ y, x + 1 };
                if (neighbor[1] > map[0].len - 1) continue;
            },
            2 => {
                neighbor = .{ y + 1, x };
                if (neighbor[0] > map.len - 1) continue;
            },
            3 => {
                neighbor = .{ y, std.math.sub(usize, x, 1) catch continue };
            },
        }
        if (i +% 2 == dir_last) continue;
        switch (map[neighbor[0]][neighbor[1]]) {
            .forest => continue,
            .path => {
                neighbors_counter += 1;
            },
            .up, .right, .down, .left => |slope_tile| {
                neighbors_counter += 1;
                if (slope_tile != DIR_SLOPE_MAP[i]) continue;
                if (seen.contains(neighbor)) continue;
                seen.put(neighbor, {}) catch unreachable;
            },
        }
        neighbors.append(.{ .pos = neighbor, .dir = i }) catch unreachable;
    }

    return .{ neighbors_counter > 1, neighbors };
}

fn getLongestPath(comptime directed: bool, allocator: Allocator, start: [2]usize, goal: [2]usize, nodes: *Map([2]usize, Node)) usize
{
    var max: usize = 0;
    var queue = List(std.meta.Tuple(&.{ usize, [2]usize, Map([2]usize, void) })).init(allocator);
    defer queue.deinit();
    queue.append(.{ 0, start, Map([2]usize, void).init(allocator) }) catch unreachable;

    while (queue.popOrNull()) |state| {
        const weight = state[0];
        const pos = state[1];
        var visited = state[2];
        defer visited.deinit();
        if (pos[0] == goal[0] and pos[1] == goal[1]) {
            max = @max(max, weight);
            continue;
        }
        visited.put(pos, {}) catch unreachable;
        const node = nodes.get(pos).?;

        for (node.edges.items) |edge| {
            if (directed and !edge.traversable) continue;
            if (visited.contains(edge.destination)) continue;
            const visited_cloned = visited.clone() catch unreachable;
            queue.append(.{ weight + edge.weight, edge.destination, visited_cloned }) catch unreachable;
        }
    }

    return max;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 1000000, 10000, 1);
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

    try std.testing.expectEqual(@as(usize, 94), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 154), part2(parsed));
}