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

const INPUT_PATH = "input/25";


const Parsed = struct {
    graph: Graph,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.graph.deinit();
    }
};

const Graph = struct {
    nodes: Map(u32, Node),
    edges: List(Edge),
    prng: std.rand.DefaultPrng,

    const Self = @This();

    fn contract(self: *Self) void {
        const random = self.prng.random();

        const idx = random.uintLessThan(usize, self.edges.items.len);

        const removed = self.edges.swapRemove(idx);
        const n1 = removed.node1;
        const n2 = removed.node2;
        assert(n1 != n2);
        assert(n1 < n2);

        var i: usize = 0;
        while (i < self.edges.items.len) {
            const edge = &self.edges.items[i];
            if (edge.node1 == n1 and edge.node2 == n2) {
                _ = self.edges.swapRemove(i);
                continue;
            }
            i += 1;
            if (edge.node1 == n2) {
                edge.node1 = n1;
            } else if (edge.node2 == n2) {
                edge.node2 = n1;
            } else continue;

            if (edge.node1 > edge.node2) std.mem.swap(u32, &edge.node1, &edge.node2);

        }
    }

    fn componentSize(self: *const Self, node1: Node, cuts: [3]u64, seen: *Map(u32, void)) usize {
        var accum: usize = 0;
        for (node1.neighbors.items) |node2| {
            const edge_label = Node.edgeName(node1.label, node2);
            if (edge_label == cuts[0] or edge_label == cuts[1] or edge_label == cuts[2]) continue;
            if (seen.contains(node2)) continue;
            seen.put(node2, {}) catch unreachable;
            accum += self.componentSize(self.nodes.get(node2).?, cuts, seen);
        }
        return 1 + accum;
    }

    fn getComponentSize(self: *const Self, start1: u32, start2: u32, cut1: u64, cut2: u64, cut3: u64) [2]usize {
        var seen = Map(u32, void).init(self.nodes.allocator);
        defer seen.deinit();

        var sizes: [2]usize = undefined;
        const node1 = self.nodes.get(start1).?;
        seen.put(start1, {}) catch unreachable;
        sizes[0] = self.componentSize(node1, .{ cut1, cut2, cut3 }, &seen);
        seen.clearRetainingCapacity();
        const node2 = self.nodes.get(start2).?;
        seen.put(start2, {}) catch unreachable;
        sizes[1] = self.componentSize(node2, .{ cut1, cut2, cut3 }, &seen);

        return sizes;
    }

    fn clone(self: *const Self) !Self {

        return .{
            .nodes = self.nodes,
            .edges = try self.edges.clone(),
            .prng = std.rand.DefaultPrng.init(@intCast(util.abs(std.time.nanoTimestamp()))),
        };
    }

    fn deinit(self: *Self) void {
        var it = self.nodes.valueIterator();
        while (it.next()) |node| node.deinit();
        self.nodes.deinit();
        self.edges.deinit();
    }
};

const Node = struct {
    label: u32,
    neighbors: List(u32),

    const Self = @This();

    fn componentSize(self: *const Self, nodes: *const Map(u32, Self), seen: *Map(u32, void)) usize {
        var accum: usize = 0;
        for (self.neighbors.items) |node| {
            if (seen.contains(node)) continue;
            seen.put(node, {}) catch unreachable;
            accum += nodes.get(node).?.componentSize(nodes, seen);
        }
        return 1 + accum;
    }

    fn edgeName(n1: u32, n2: u32) u64 {
        if (n1 > n2) return (@as(u64, n2) << 32) + n1;
        return (@as(u64, n1) << 32) + n2;
    }

    fn init(allocator: Allocator, label: u32) Self {
        return .{
            .label = label,
            .neighbors = List(u32).init(allocator),
        };
    }

    fn clone(self: *const Self) !Self {
        return .{
            .label = self.label,
            .neighbors = try self.neighbors.clone(),
        };
    }

    fn deinit(self: *Self) void {
        self.neighbors.deinit();
    }
};

const Edge = struct {
    label: u64,
    node1: u32,
    node2: u32,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var nodes = Map(u32, Node).init(allocator);

    var it = tokenize(u8, raw, "\n");
    assert(raw[raw.len - 1] == '\n');

    while (it.next()) |line| {
        const lhs: u32 = @as(u24, @bitCast(line[0..3].*));
        _ = nodes.getOrPutValue(lhs, Node.init(allocator, lhs)) catch unreachable;
        var i: usize = 4;
        while (i + 2 < line.len) : (i += 4) {
            const rhs: u32 = @as(u24, @bitCast(line[i + 1..][0..3].*));
            const rhs_edges = &((nodes.getOrPutValue(rhs, Node.init(allocator, rhs)) catch unreachable).value_ptr.neighbors);
            const lhs_edges = &nodes.getEntry(lhs).?.value_ptr.neighbors;
            lhs_edges.append(rhs) catch unreachable;
            rhs_edges.append(lhs) catch unreachable;
        }
    }

    var seen = Map(u64, void).init(allocator);
    defer seen.deinit();
    var edges = List(Edge).init(allocator);
    var it_nodes = nodes.valueIterator();
    while (it_nodes.next()) |node| {
        for (node.neighbors.items) |node2| {
            const label = Node.edgeName(node.label, node2);
            if (seen.contains(label)) continue;
            seen.put(label, {}) catch unreachable;
            var n1 = node.label;
            var n2 = node2;
            if (n1 > n2) std.mem.swap(u32, &n1, &n2);
            assert(n1 < n2);
            edges.append(.{
                .label = label,
                .node1 = n1,
                .node2 = n2,
            }) catch unreachable;
        }
    }

    return .{
        .graph = .{
            .nodes = nodes,
            .edges = edges,
            .prng = std.rand.DefaultPrng.init(@intCast(util.abs(std.time.nanoTimestamp()))),
        },
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const graph = parsed.graph;

    var counter: usize = 0;
    while (true) {
        counter += 1;
        var current_graph = Graph{
            .nodes = graph.nodes,
            .edges = graph.edges.clone() catch unreachable,
            .prng = std.rand.DefaultPrng.init(@intCast(util.abs(std.time.nanoTimestamp()))),
        };
        defer current_graph.edges.deinit();

        for (0..current_graph.nodes.count() - 2) |_| current_graph.contract();

        const cuts = current_graph.edges.items;
        if (cuts.len == 3) {
            const cut1 = cuts[0].label;
            const cut2 = cuts[1].label;
            const cut3 = cuts[2].label;
            const start1: u32 = @intCast(cut1 >> 32);
            const start2: u32 = @intCast(cut1 & 0xffffffff);

            const sizes = graph.getComponentSize(start1, start2, cut1, cut2, cut3);

            if (sizes[0] + sizes[1] == graph.nodes.count()) {
//                 print("{}\n", .{ counter });
                return sizes[0] * sizes[1];
            }
        }
    }

    unreachable;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;

    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    const p1 = part1(parsed);

    print("Part1: {}\n", .{ p1 });

    try util.benchmark(INPUT_PATH, parseInput, part1, part1, 10000, 1, 1);
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

    try std.testing.expectEqual(@as(usize, 54), part1(parsed));
}