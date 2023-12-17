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

const INPUT_PATH = "input/17";


const Parsed = struct {
    heatmap: [][]const usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.heatmap) |row| self.allocator.free(row);
        self.allocator.free(self.heatmap);
    }
};

const ALL_DIRS: [4]u2 = .{
    0,  // East
    1,  // South
    2,  // West
    3,  // North
};

const ALL_DIFFS: [4][2]isize = .{
    .{ 0, 1 },  // East
    .{ 1, 0 },  // South
    .{ 0, -1 }, // West
    .{ -1, 0 }, // North
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var heatmap = List([]const usize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        const row = allocator.alloc(usize, line.len) catch unreachable;
        for (line, 0..) |c, i| {
            row[i] = c - '0';
        }
        heatmap.append(row) catch unreachable;
    }

    return .{
        .heatmap = heatmap.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const heatmap = parsed.heatmap;

    return minimizeHeatLoss(1, 3, parsed.allocator, heatmap);
}

fn part2(parsed: Parsed) usize
{
    const heatmap = parsed.heatmap;

    return minimizeHeatLoss(4, 10, parsed.allocator, heatmap);
}

fn minimizeHeatLoss(comptime min_straight: comptime_int, comptime max_straight: comptime_int, allocator: Allocator, heatmap: [][]const usize) usize
{
    var queue = std.PriorityQueue([6]usize, void, lessThanOrder).init(allocator, {});
    defer queue.deinit();
    var seen = Map([4]usize, usize).init(allocator);
    defer seen.deinit();

    queue.add(.{ heatmap.len + heatmap[0].len - 2, 0, 0, 0, 0, 0 }) catch unreachable;

    while (queue.removeOrNull()) |node| {
        const accum = node[1];
        const dir: u2 = @intCast(node[2]);
        const straight = node[3];
        const pos = [2]usize{ node[4], node[5] };

        if (pos[0] == heatmap.len - 1 and pos[1] == heatmap[0].len - 1) {
            return accum;
        }

        const neighbors = getNeighbors(min_straight, max_straight, heatmap, pos, dir, straight);
        for (neighbors, 0..) |neighbor_maybe, i| {
            if (neighbor_maybe) |neighbor| {
                var add = heatmap[neighbor[0]][neighbor[1]];
                const dir_next = ALL_DIRS[i];
                if (min_straight > 1) {
                    const diff: [2]isize = util.intCastArray(isize, neighbor) - util.intCastArray(isize, pos);
                    if (!std.mem.eql(isize, &diff, &ALL_DIFFS[i])) {
                        var pos_inter: [2]usize = pos;
                        for (0..min_straight - 1) |_| {
                            pos_inter = @as(@Vector(2, usize), @intCast(util.intCastArray(isize, pos_inter) + ALL_DIFFS[i]));
                            add += heatmap[pos_inter[0]][pos_inter[1]];
                        }
                    }
                }

                const accum_next = accum + add;
                const key = [2]usize{ dir_next, if (dir_next == dir) straight + 1 else min_straight } ++ neighbor;
                const manhattan = heatmap.len + heatmap[0].len - neighbor[0] - neighbor[1] - 2;
                if (seen.get(key)) |accum_prev| {
                    if (accum_prev <= accum_next) continue;
                    queue.update(
                        .{ accum_prev + manhattan, accum_prev } ++ key,
                        .{ accum_next + manhattan, accum_next } ++ key
                    ) catch unreachable;
                } else {
                    queue.add(.{ accum_next + manhattan, accum_next } ++ key) catch unreachable;
                }
                seen.put(key, accum_next) catch unreachable;
            }
        }
    }

    unreachable;
}

fn getNeighbors(comptime min_straight: comptime_int, comptime max_straight: comptime_int, heatmap: [][]const usize, pos: [2]usize, dir: u2, straight: usize) [4]?[2]usize
{
    var neighbors: [4]?[2]usize = .{ null, null, null, null };

    for (ALL_DIFFS, 0..) |add, i| {
        if (dir +% 2 == ALL_DIRS[i]) continue;
        if (straight == max_straight and dir == ALL_DIRS[i]) continue;

        var neighbor = util.intCastArray(isize, pos) + add;
        if (min_straight > 1) {
            if (dir != ALL_DIRS[i]) {
                neighbor = util.intCastArray(isize, pos) + util.intCastArray(isize, add) * ([_]isize{ min_straight } ** 2);
            }
        }
        if (neighbor[0] < 0 or neighbor[1] < 0) continue;
        if (neighbor[0] > heatmap.len - 1 or neighbor[1] > heatmap[0].len - 1) continue;
        neighbors[i] = .{ @intCast(neighbor[0]), @intCast(neighbor[1]) };
    }

    return neighbors;
}

fn lessThanOrder(context: void, a: [6]usize, b: [6]usize) std.math.Order
{
    _ = context;

    // For some reason this line is much slower
    // than the following abomination
    //return std.mem.order(usize, &a, &b);

    if (a[0] == b[0]) {
        if (a[1] == b[1]) {
            if (a[2] == a[2]) {
                if (a[3] == a[3]) {
                    if (a[4] == b[4]) {
                        return std.math.order(a[5], b[5]);
                    } else {
                        return std.math.order(a[4], b[4]);
                    }
                } else {
                    return std.math.order(a[3], b[3]);
                }
            } else {
                return std.math.order(a[2], b[2]);
            }
        } else {
            return std.math.order(a[1], b[1]);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 100, 100);
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

    try std.testing.expectEqual(@as(usize, 102), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 94), part2(parsed));
}