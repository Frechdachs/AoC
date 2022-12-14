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

const INPUT_PATH = "input/14";
const TEST_INPUT_PATH = "input/14test";


const Parsed = struct {
    cones: Cave,
    floor_y: usize,
    wall_count: usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.cones.deinit();
    }
};

// u8 instead of bool to make it easier to manually vectorize
const Cave = struct {
    items: []u8,
    height: usize,
    width: usize,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, height: usize, width: usize) Self {
        const items = allocator.alloc(u8, height * width) catch unreachable;
        std.mem.set(u8, items, 0);

        return .{
            .items = items,
            .height = height,
            .width = width,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.items);
    }

    fn set(self: *Self, pos: [2]usize) void {
        const i = pos[0];
        const j = pos[1];

        self.items[i * self.width + j] = 1;
    }

    fn get(self: *const Self, pos: [2]usize) u8 {
        const i = pos[0];
        const j = pos[1];

        return self.items[i * self.width + j];
    }

    fn get32(self: *const Self, pos: [2]usize) @Vector(32, u8) {
        const i = pos[0];
        const j = pos[1];

        return self.items[i * self.width + j..][0..32].*;
    }

    fn set32(self: *Self, pos: [2]usize, values: @Vector(32, u8)) void {
        const i = pos[0];
        const j = pos[1];

        self.items[i * self.width + j..][0..32].* = values;
    }

    fn contains(self: *const Self, pos: [2]usize) bool {
        return self.get(pos) == 1;
    }

    fn clone(self: *const Self) !Self {
        const items = try self.allocator.alloc(u8, self.height * self.width);
        std.mem.copy(u8, items, self.items);

        return .{
            .items = items,
            .height = self.height,
            .width = self.width,
            .allocator = self.allocator,
        };
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var floor_y: usize = 0;
    var it = tokenize(u8, raw, ", ->\n");
    while (it.next()) |_| {
        const y_str = it.next().?;
        const y = parseInt(usize, y_str, 10) catch unreachable;
        floor_y = @max(floor_y, y + 2);
    }

    var cones = Cave.init(allocator, floor_y, 500 + floor_y);
    it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var last: ?[2]usize = null;
        var it_line = tokenize(u8, line, ", ->");
        while (it_line.next()) |x_str| {
            const y_str = it_line.next().?;
            const next = [2]usize{
                parseInt(usize, y_str, 10) catch unreachable,
                parseInt(usize, x_str, 10) catch unreachable,
            };
            if (last) |prev| {
                const start_y = prev[0];
                const start_x = prev[1];
                const end_y = next[0];
                const end_x = next[1];
                if (start_y == end_y) {
                    var i: usize = @min(start_x, end_x);
                    while (i <= @max(start_x, end_x)) : (i += 1) {
                        cones.set(.{ start_y, i });
                    }
                } else if (start_x == end_x) {
                    var i: usize = @min(start_y, end_y);
                    while (i <= @max(start_y, end_y)) : (i += 1) {
                        cones.set(.{ i, start_x });
                    }
                } else {
                    unreachable;
                }
            }
            last = next;
        }
    }

    // Fill the cones from top to bottom
    // And count all the elements while we are at it
    // Vectorized for speed
    var accum: usize = 0;
    var i: usize = 1;
    while (i < floor_y) : (i += 1) {
        var j = 500 - i;
        var accumvec: @Vector(32, u8) = .{ 0 } ** 32;
        while (j + 32 <= 500 + i) : (j += 32) {
            const above1 = cones.get32(.{ i - 1, j - 1});
            const above2 = cones.get32(.{ i - 1, j});
            const above3 = cones.get32(.{ i - 1, j + 1});
            const current = cones.get32(.{ i, j });

            const new = (above1 & above2 & above3) | current;

            accumvec += above2;
            if (i + 1 == floor_y) accumvec += new;

            cones.set32(
                .{ i, j },
                new,
            );
        }
        accum += @reduce(.Add, @intCast(@Vector(32, usize), accumvec));

        while (j <= 500 + i) : (j += 1) {
            const above1 = cones.get(.{ i - 1, j - 1 });
            const above2 = cones.get(.{ i - 1, j });
            const above3 = cones.get(.{ i - 1, j + 1 });
            if (above1 + above2 + above3 == 3) cones.set(.{ i, j });

            accum += above2;
            if (i + 1 == floor_y) accum += cones.get(.{ i, j });
        }
    }

    return .{
        .cones = cones,
        .floor_y = floor_y,
        .wall_count = accum,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var i: usize = 0;
    var cave = parsed.cones.clone() catch unreachable;
    defer cave.deinit();
    outer: while (true) : (i += 1) {
        var pos = [2]usize{ 0, 500 };
        while (true) {
            var stopped = false;
            var new_pos = [2]usize{ pos[0] + 1, pos[1] };
            if (cave.contains(new_pos)) {
                new_pos = .{ pos[0] + 1, pos[1] - 1 };
                if (cave.contains(new_pos)) {
                    new_pos = .{ pos[0] + 1, pos[1] + 1 };
                    if (cave.contains(new_pos)) {
                        stopped = true;
                    }
                }
            }
            if (!stopped) {
                if (new_pos[0] == parsed.floor_y - 2) break :outer;
                pos = new_pos;
            } else {
                cave.set(pos);
                break;
            }
        }
    }

    return i;
}

fn part2(parsed: Parsed) usize
{
    const n = parsed.floor_y;
    const wall_count = parsed.wall_count;

    return n * n - wall_count;
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
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part1(parsed) == 24);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 93);
}