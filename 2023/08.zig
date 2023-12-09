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

const INPUT_PATH = "input/08";


const Parsed = struct {
    instructions: []const u8,
    start_nodes: [][3]u5,
    network: Network,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.start_nodes);
    }
};

const Network = struct {
    // A lot of wasted space, but I felt like trying something new (and stupid) :)
    nodes: [26][26][26][2][3]u5,

    const Self = @This();

    fn setNode(self: *Self, node: [3]u5, left: [3]u5, right: [3]u5) void {
        self.nodes[node[0]][node[1]][node[2]][0] = left;
        self.nodes[node[0]][node[1]][node[2]][1] = right;
    }

    fn nextNode(self: *const Self, current: [3]u5, instruction: u8) [3]u5 {
        assert(instruction == 'R' or instruction == 'L');

        const idx: usize = if (instruction == 'R') 1 else 0;

        return self.nodes[current[0]][current[1]][current[2]][idx];
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var network: Network = .{ .nodes = undefined };

    var it = tokenize(u8, raw, "\n\n");

    const instructions = it.next().?;
    var start_nodes = List([3]u5).init(allocator);
    var it_lines = tokenize(u8, it.rest(), "\n");

    while (it_lines.next()) |line| {
        var node: [3]u5 = undefined;
        var left: [3]u5 = undefined;
        var right: [3]u5 = undefined;

        for (line[0..3], 0..) |c, i| node[i] = @intCast(c - 'A');
        for (line[7..10], 0..) |c, i| left[i] = @intCast(c - 'A');
        for (line[12..15], 0..) |c, i| right[i] = @intCast(c - 'A');

        network.setNode(node, left, right);
        if (node[2] == 0) start_nodes.append(node) catch unreachable;
    }

    assert(start_nodes.items.len > 0);

    return .{
        .instructions = instructions,
        .start_nodes = start_nodes.toOwnedSlice() catch unreachable,
        .network = network,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const network = parsed.network;
    const instructions = parsed.instructions;

    const start = [_]u5{ 0, 0, 0 };
    const goal = [_]u5{ 25, 25, 25 };

    var steps: usize = 0;
    var current = start;

    while (!std.mem.eql(u5, &current, &goal)) : (steps += 1) {
        current = network.nextNode(current, instructions[steps % instructions.len]);
    }

    return steps;
}

fn part2(parsed: Parsed) usize
{
    const network = parsed.network;
    const instructions = parsed.instructions;
    const start_nodes = parsed.start_nodes;

    var accum: usize = 1;

    for (start_nodes) |start| {
        var current = start;
        var steps: usize = 0;

        while (true) : (steps += 1) {
            current = network.nextNode(current, instructions[steps % instructions.len]);
            if (current[2] == 25) {
                accum = util.lcm(accum, steps + 1);
                break;
            }
        }
    }

    return accum;
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

    try std.testing.expectEqual(@as(usize, 2), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test2", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 6), part2(parsed));
}