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

const INPUT_PATH = "input/23";
const TEST_INPUT_PATH = "input/23test";


const Parsed = struct {
    grove: Grove,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.grove.deinit();
    }
};

const Grove = struct {
    current_map: Map([2]isize, void),
    next_map: Map([2]isize, void),
    direction: u2,
    max_y: isize,
    min_y: isize,
    max_x: isize,
    min_x: isize,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator) Self {
        const current_map = Map([2]isize, void).init(allocator);
        const next_map = Map([2]isize, void).init(allocator);

        return .{
            .current_map = current_map,
            .next_map = next_map,
            .direction = 0,
            .max_y = 0,
            .min_y = 0,
            .max_x = 0,
            .min_x = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.current_map.deinit();
        self.next_map.deinit();
    }

    fn clone(self: *const Self) Self {
        var cloned = self.*;
        cloned.current_map = self.current_map.clone() catch unreachable;
        cloned.next_map = Map([2]isize, void).init(self.allocator);

        return cloned;
    }

    fn setCurrent(self: *Self, elf: [2]isize) void {
        self.set(&self.current_map, elf);
    }

    fn setNext(self: *Self, elf: [2]isize) void {
        self.set(&self.next_map, elf);
    }

    inline fn set(self: *Self, map: *@TypeOf(self.current_map), elf: [2]isize) void {
        map.put(elf, {}) catch unreachable;
        const elf_y = elf[0];
        const elf_x = elf[1];
        self.max_y = @max(self.max_y, elf_y);
        self.min_y = @min(self.min_y, elf_y);
        self.max_x = @max(self.max_x, elf_x);
        self.min_x = @min(self.min_x, elf_x);
    }

    fn hasNeighborDirection(self: *const Self, direction: u2, elf: [2]isize) bool {
        const elf_y = elf[0];
        const elf_x = elf[1];
        const points: [3][2]isize = switch (direction) {
            0 => .{ .{ elf_y - 1, elf_x - 1 }, .{ elf_y - 1, elf_x }, .{ elf_y - 1, elf_x + 1 } },
            1 => .{ .{ elf_y + 1, elf_x - 1 }, .{ elf_y + 1, elf_x }, .{ elf_y + 1, elf_x + 1 } },
            2 => .{ .{ elf_y + 1, elf_x - 1 }, .{ elf_y, elf_x - 1 }, .{ elf_y - 1, elf_x - 1 } },
            3 => .{ .{ elf_y + 1, elf_x + 1 }, .{ elf_y, elf_x + 1 }, .{ elf_y - 1, elf_x + 1 } },
        };
        for (points) |p| {
            if (self.current_map.contains(p)) return true;
        }

        return false;
    }

    fn getNewElf(direction: u2, old_elf: [2]isize) [2]isize {
        const elf_y = old_elf[0];
        const elf_x = old_elf[1];
        const new_elf: [2]isize = switch (direction) {
            0 => .{ elf_y - 1, elf_x },
            1 => .{ elf_y + 1, elf_x },
            2 => .{ elf_y, elf_x - 1 },
            3 => .{ elf_y, elf_x + 1 },
        };

        return new_elf;
    }

    fn step(self: *Self) bool {
        var candidates = List([2][2]isize).init(self.allocator);
        defer candidates.deinit();
        var contested = Map([2]isize, usize).init(self.allocator);
        defer contested.deinit();
        defer self.next_map.clearRetainingCapacity();

        self.max_y = std.math.minInt(isize);
        self.min_y = std.math.maxInt(isize);
        self.max_x = std.math.minInt(isize);
        self.min_x = std.math.maxInt(isize);

        var it = self.current_map.iterator();
        var moved = false;
        while (it.next()) |kv| {
            const elf = kv.key_ptr.*;
            const local_direction = self.direction;
            var add: u8 = 0;
            while (add < 4) : (add += 1) {
                const curr_direction = local_direction +% @intCast(u2, add);
                if (!self.hasNeighborDirection(curr_direction, elf)) {
                    if (
                        add == 0 and
                        !self.hasNeighborDirection(local_direction +% 1, elf) and
                        !self.hasNeighborDirection(local_direction +% 2, elf) and
                        !self.hasNeighborDirection(local_direction +% 3, elf)
                    ) {
                        add = 4;
                        continue;
                    }
                    const new_elf = Grove.getNewElf(curr_direction, elf);
                    candidates.append(.{ elf, new_elf }) catch unreachable;
                    contested.put(new_elf, (contested.get(new_elf) orelse 0) + 1) catch unreachable;
                    break;
                }
            } else {
                self.setNext(elf);
            }
        }

        for (candidates.items) |candidate| {
            const old_elf = candidate[0];
            const new_elf = candidate[1];
            if (contested.get(new_elf).? == 1) {
                moved = true;
                self.setNext(new_elf);
            } else {
                self.setNext(old_elf);
            }
        }

        std.mem.swap(@TypeOf(self.current_map), &self.current_map, &self.next_map);
        self.direction +%= 1;

        return moved;
    }

    fn enclosedEmpty(self: *const Self) usize {
        return @intCast(usize, (self.max_y + 1 - self.min_y) * (self.max_x + 1 - self.min_x) - self.current_map.count());
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var grove = Grove.init(allocator);
    var it = tokenize(u8, raw, "\n");
    var i: usize = 0;
    while (it.next()) |line| : (i += 1) {
        for (line) |c, j| {
            if (c == '#') grove.setCurrent(.{ @intCast(isize, i), @intCast(isize, j) });
        }
    }

    return .{
        .grove = grove,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var grove = parsed.grove.clone();
    defer grove.deinit();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = grove.step();
    }

    return grove.enclosedEmpty();
}

fn part2(parsed: Parsed) usize
{
    var grove = parsed.grove.clone();
    defer grove.deinit();

    var i: usize = 0;
    while (grove.step()) i += 1;

    return i + 1;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 10);
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
    try std.testing.expect(part1(parsed) == 110);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 20);
}