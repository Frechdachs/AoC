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

const INPUT_PATH = "input/24";
const TEST_INPUT_PATH = "input/24test";


const Parsed = struct {
    basin: Basin,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.basin.deinit();
    }
};

const Direction = enum(u8) {
    n = '^',
    e = '>',
    s = 'v',
    w = '<',
};

const Blizzard = struct {
    direction: Direction,
    pos: [2]usize,

    const Self = @This();

    fn step(self: *const Self, height: usize, width: usize) Self {
        var new_pos: [2]usize = switch (self.direction) {
            .n => .{ self.pos[0] - 1, self.pos[1] },
            .e => .{ self.pos[0], self.pos[1] + 1 },
            .s => .{ self.pos[0] + 1, self.pos[1] },
            .w => .{ self.pos[0], self.pos[1] - 1 },
        };
        if (new_pos[0] == 0) new_pos[0] = height;
        if (new_pos[0] == height + 1) new_pos[0] = 1;
        if (new_pos[1] == 0) new_pos[1] = width;
        if (new_pos[1] == width + 1) new_pos[1] = 1;

        return .{
            .direction = self.direction,
            .pos = new_pos,
        };
    }
};

const Basin = struct {
    height: usize,
    width: usize,
    blizzards: List(Blizzard),
    allocator: Allocator,

    const Self = @This();

    fn deinit(self: *Self) void {
        self.blizzards.deinit();
    }

    fn step(self: *const Self, direction: Direction, pos: [2]usize) ?[2]usize {
        // Don't leave the map
        if (pos[0] == 0 and pos[1] == 1 and direction == .n) return null;
        if (pos[0] == self.height + 1 and pos[1] == self.width and direction == .s) return null;

        const new_pos: [2]usize = switch (direction) {
            .n => .{ pos[0] - 1, pos[1] },
            .e => .{ pos[0], pos[1] + 1 },
            .s => .{ pos[0] + 1, pos[1] },
            .w => .{ pos[0], pos[1] - 1 },
        };

        // Allow start and end positions
        if (new_pos[0] == self.height + 1 and new_pos[1] == self.width) return new_pos;
        if (new_pos[0] == 0 and new_pos[1] == 1) return new_pos;

        // Don't enter the walls
        if (
            new_pos[0] == 0 or new_pos[0] == self.height + 1 or
            new_pos[1] == 0 or new_pos[1] == self.width + 1
        ) return null;

        return new_pos;
    }

    fn getFastestWay(self: *const Self, trip_limit: usize) usize {
        // Hack to make the list mutable, because currently
        // lists have to be mutable to be cloned,
        // already fixed in master, but not in 0.10.0
        var s = self.*;
        var blizzards = s.blizzards.clone() catch unreachable;
        var new_blizzards = List(Blizzard).init(self.allocator);
        var blocked = Map([2]usize, void).init(self.allocator);
        var positions = List([2]usize).init(self.allocator);
        var new_positions = List([2]usize).init(self.allocator);
        defer blizzards.deinit();
        defer new_blizzards.deinit();
        defer blocked.deinit();
        defer positions.deinit();
        defer new_positions.deinit();

        const cycle = util.lcm(self.height, self.width);
        var seen = Map([3]usize, void).init(self.allocator);
        seen.ensureTotalCapacity(@intCast(u32, self.height * self.width * cycle / 3)) catch unreachable;
        defer seen.deinit();

        var start = [_]usize{ 0, 1 };
        var goal = [_]usize{ self.height + 1, self.width };

        var i: usize = 0;
        var trips: usize = 0;
        while (trips < trip_limit) : (trips += 1) {
            seen.clearRetainingCapacity();
            positions.clearRetainingCapacity();
            positions.append(start) catch unreachable;

            outer: while (true) : (i += 1) {
                blocked.clearRetainingCapacity();
                new_blizzards.clearRetainingCapacity();
                new_positions.clearRetainingCapacity();
                const cycle_pos = i % cycle;

                for (blizzards.items) |*blizzard| {
                    const new_blizzard = blizzard.step(self.height, self.width);
                    new_blizzards.append(new_blizzard) catch unreachable;
                    blocked.put(new_blizzard.pos, {}) catch unreachable;
                }
                std.mem.swap(List(Blizzard), &blizzards, &new_blizzards);

                defer std.mem.swap(List([2]usize), &positions, &new_positions);

                for (positions.items) |pos| {
                    for ([_]?Direction{ .n, .e, .s, .w, null }) |direction| {
                        const new_pos = if (direction) |d| (
                            self.step(d, pos) orelse continue
                        ) else pos;
                        if (std.mem.eql(usize, &new_pos, &goal)) break :outer;
                        if (blocked.contains(new_pos)) continue;
                        if (seen.contains(.{ new_pos[0], new_pos[1], cycle_pos })) continue;
                        new_positions.append(new_pos) catch unreachable;
                        seen.put(.{ new_pos[0], new_pos[1], cycle_pos }, {}) catch unreachable;
                    }
                }
            }
            std.mem.swap([2]usize, &start, &goal);
        }

        return i + trips;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var blizzards = List(Blizzard).init(allocator);
    var it = tokenize(u8, raw, "\n");
    var i: usize = 0;
    var width: usize = 0;
    while (it.next()) |line| : (i += 1) {
        if (line[2] == '#') continue;
        width = line.len - 2;
        for (line[1..line.len - 1]) |c, j| {
            if (c == '.') continue;
            blizzards.append(.{
                .direction = @intToEnum(Direction, c),
                .pos = .{ i, j + 1 },
            }) catch unreachable;
        }
    }

    const basin = .{
        .height = i - 2,
        .width = width,
        .blizzards = blizzards,
        .allocator = allocator,
    };

    return .{
        .basin = basin,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const basin = parsed.basin;

    return basin.getFastestWay(1);
}

fn part2(parsed: Parsed) usize
{
    const basin = parsed.basin;

    return basin.getFastestWay(3);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10, 10);
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
    try std.testing.expect(part1(parsed) == 18);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 54);
}