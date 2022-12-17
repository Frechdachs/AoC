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

const INPUT_PATH = "input/17";
const TEST_INPUT_PATH = "input/17test";


const Parsed = struct {
    jets: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

const Rock = enum(u8) {
    minus = 0,
    plus = 1,
    corner = 2,
    line = 3,
    square = 4,

    const Self = @This();

    fn getPoints(self: Self, pos: [2]usize) std.BoundedArray([2]usize, 5) {
        var points = std.BoundedArray([2]usize, 5).init(0) catch unreachable;
        switch (self) {
            .minus => {
                points.appendSliceAssumeCapacity(
                    &[_][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } }
                );
            },
            .plus => {
                points.appendSliceAssumeCapacity(
                    &[_][2]usize{ .{ 0, 1 }, .{ 1, 0 }, .{ 1, 1 }, .{ 1, 2 }, .{ 2, 1 } }
                );
            },
            .corner => {
                points.appendSliceAssumeCapacity(
                    &[_][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 1, 2 }, .{ 2, 2 } }
                );
            },
            .line => {
                points.appendSliceAssumeCapacity(
                    &[_][2]usize{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } }
                );
            },
            .square => {
                points.appendSliceAssumeCapacity(
                    &[_][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 }, .{ 1, 1 } }
                );
            },
        }
        for (points.slice()) |*p| {
            p.* = .{ pos[0] + p.*[0], pos[1] + p.*[1] };
        }

        return points;
    }
};

const Mapping = struct {
    rock: Rock,
    idx: usize,
};

const Chamber = struct {
    grid: Map([2]usize, void),
    cache: Map(Mapping, [2]usize),
    jets: []const u8,
    allocator: Allocator,

    prev_rock: Rock = .square,
    jet_idx: usize = 0,
    height: usize = 0,
    column_heights: [7]usize = .{ 0 } ** 7,

    const Self = @This();

    fn init(allocator: Allocator, jets: []const u8) Self {
        const grid = Map([2]usize, void).init(allocator);
        const cache = Map(Mapping, [2]usize).init(allocator);

        return .{
            .grid = grid,
            .cache = cache,
            .jets = jets,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.grid.deinit();
        self.cache.deinit();
    }

    fn contains(self: *const Self, pos: [2]usize) bool {
        return self.grid.contains(pos);
    }

    fn put(self: *Self, pos: [2]usize) void {
        self.grid.put(pos, {}) catch unreachable;
        self.column_heights[pos[1]] = @max(self.column_heights[pos[1]], pos[0] + 1);
    }

    fn checkPos(self: *const Self, shape: Rock, pos: [2]usize) bool {
        const points = shape.getPoints(pos);
        for (points.slice()) |p| {
            if (p[1] >= 7) return false;
            if (self.contains(p)) return false;
        }

        return true;
    }

    fn flatTop(self: *const Self) bool {
        return (
            self.column_heights[0] == (
                self.column_heights[1] &
                self.column_heights[2] &
                self.column_heights[3] &
                self.column_heights[4] &
                self.column_heights[5] &
                self.column_heights[6]
            )
        );
    }

    fn simulate(self: *Self, comptime limit: usize) usize {
        var accum: usize = 0;

        var i: usize = 0;
        while (i < limit) : (i += 1) {

            if (self.flatTop()) {

                if (self.cache.get(.{ .rock = self.prev_rock, .idx = self.jet_idx })) |prev| {
                    const inc = i - prev[0];
                    const acc = self.height - prev[1];
                    while (i + inc < limit - 1) : (i += inc) {
                        accum += acc;
                    }

                } else {
                    self.cache.put(
                        .{ .rock = self.prev_rock, .idx = self.jet_idx },
                        .{ i, self.height},
                    ) catch unreachable;
                }
            }

            self.step();
        }

        return self.height + accum;
    }

    fn step(self: *Self) void {
        const rock = @intToEnum(Rock, (@enumToInt(self.prev_rock) + 1) % 5);
        var curr_pos = [2]usize{ self.height + 3, 2 };
        while (true) {
            var new_pos: [2]usize = switch (self.jets[self.jet_idx]) {
                '<' => .{ curr_pos[0], curr_pos[1] -| 1 },
                '>' => .{ curr_pos[0], curr_pos[1] + 1 },
                else => unreachable,
            };
            self.jet_idx = (self.jet_idx + 1) % self.jets.len;
            if (self.checkPos(rock, new_pos)) curr_pos = new_pos;
            if (curr_pos[0] == 0) break;
            new_pos = .{ curr_pos[0] - 1, curr_pos[1] };
            if (!self.checkPos(rock, new_pos)) break;
            curr_pos = new_pos;
        }

        for (rock.getPoints(curr_pos).slice()) |p| {
            self.put(p);
            self.height = @max(self.height, p[0] + 1);
        }

        self.prev_rock = rock;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    return .{
        .jets = raw[0..raw.len - 1],
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var chamber = Chamber.init(parsed.allocator, parsed.jets);
    defer chamber.deinit();
    const result = chamber.simulate(2022);

    return result;
}

fn part2(parsed: Parsed) usize
{
    var chamber = Chamber.init(parsed.allocator, parsed.jets);
    defer chamber.deinit();
    const result = chamber.simulate(1_000_000_000_000);

    return result;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 100, 10);
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
    try std.testing.expect(part1(parsed) == 3068);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 1514285714288);
}