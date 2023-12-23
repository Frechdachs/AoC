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

const INPUT_PATH = "input/22";


const Parsed = struct {
    bricks: []Brick,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.bricks);
    }
};

const Brick = struct {
    x: [2]usize,
    y: [2]usize,
    z: [2]usize,

    const Self = @This();

    fn supportedBy(self: *const Self, other: Self) bool {
        if (self.x[0] > other.x[1] or self.x[1] < other.x[0]) return false;
        if (self.y[0] > other.y[1] or self.y[1] < other.y[0]) return false;
        return self.z[0] == other.z[1] + 1;
    }

    fn fall(self: *Self, steps: usize) void {
        self.z[0] -= steps;
        self.z[1] -= steps;
    }

    fn sortByMinHeight(_: void, a: Self, b: Self) bool {
        return a.z[0] < b.z[0];
    }
};

const Link = struct {
    supported: List(usize),
    supports: List(usize),

    const Self = @This();

    fn init(allocator: Allocator) Self {
        return .{
            .supported = List(usize).init(allocator),
            .supports = List(usize).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.supported.deinit();
        self.supports.deinit();
    }

    fn createLinks(allocator: Allocator, bricks: []Brick) ![]Self {
        var links = try List(Self).initCapacity(allocator, bricks.len);
        for (bricks) |_| links.appendAssumeCapacity(Self.init(allocator));
        for (bricks, 0..) |b1, i| {
            if (b1.z[0] == 1) try links.items[i].supported.append(std.math.maxInt(usize));
            for (bricks[i + 1..], i + 1..) |b2, j| {
                if (b2.supportedBy(b1)) {
                    try links.items[i].supports.append(j);
                    try links.items[j].supported.append(i);
                }
            }
        }
        return try links.toOwnedSlice();
    }

    fn destroyLinks(allocator: Allocator, links: []Self) void {
        for (links) |*link| link.deinit();
        allocator.free(links);
    }

    fn willFall(self: *const Self, removed: Map(usize, void)) bool {
        for (self.supported.items) |block| if (!removed.contains(block)) return false;
        return true;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var bricks = List(Brick).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        const idx_separator = std.mem.indexOf(u8, line, "~").?;
        var it_coordinates_min = tokenize(u8, line[0..idx_separator], ",");
        var it_coordinates_max = tokenize(u8, line[idx_separator + 1..], ",");
        const x = [_]usize{
            parseUnsigned(usize, it_coordinates_min.next().?, 10) catch unreachable,
            parseUnsigned(usize, it_coordinates_max.next().?, 10) catch unreachable,
        };
        const y = [_]usize{
            parseUnsigned(usize, it_coordinates_min.next().?, 10) catch unreachable,
            parseUnsigned(usize, it_coordinates_max.next().?, 10) catch unreachable,
        };
        const z = [_]usize{
            parseUnsigned(usize, it_coordinates_min.rest(), 10) catch unreachable,
            parseUnsigned(usize, it_coordinates_max.rest(), 10) catch unreachable,
        };
        assert(x[0] <= x[1] and y[0] <= y[1] and z[0] <= z[1]);

        bricks.append(.{ .x = x, .y = y, .z = z }) catch unreachable;
    }
    sort(Brick, bricks.items, {}, Brick.sortByMinHeight);

    var bricks_temp = List(Brick).initCapacity(allocator, bricks.items.len) catch unreachable;
    defer bricks_temp.deinit();
    var height_max: usize = 0;
    for (bricks.items) |b| {
        var b1 = b;
        const fast_forward = b1.z[0] -| height_max;
        if (fast_forward > 1) b1.fall(fast_forward - 1);
        falling: while (b1.z[0] > 1) {
            for (bricks_temp.items) |b2| {
                if (b1.supportedBy(b2)) break :falling;
            }
            b1.fall(1);
        }
        height_max = @max(height_max, b1.z[1]);
        bricks_temp.appendAssumeCapacity(b1);
    }
    std.mem.swap(List(Brick), &bricks, &bricks_temp);

    return .{
        .bricks = bricks.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const bricks = parsed.bricks;

    const links = Link.createLinks(parsed.allocator, bricks) catch unreachable;
    defer Link.destroyLinks(parsed.allocator, links);

    var accum: usize = 0;
    next_block: for (links) |link| {
        for (link.supports.items) |i| if (links[i].supported.items.len == 1) continue :next_block;
        accum += 1;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const bricks = parsed.bricks;

    const links = Link.createLinks(parsed.allocator, bricks) catch unreachable;
    defer Link.destroyLinks(parsed.allocator, links);

    var accum: usize = 0;
    var removed = Map(usize, void).init(parsed.allocator);
    defer removed.deinit();
    for (0..links.len) |i| {
        removed.put(i, {}) catch unreachable;
        for (i + 1..links.len) |j| {
            if (links[j].willFall(removed)) {
                removed.put(j, {}) catch unreachable;
                accum += 1;
            }
        }
        removed.clearRetainingCapacity();
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 1000, 1000, 1000);
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

    try std.testing.expectEqual(@as(usize, 5), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 7), part2(parsed));
}