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

const INPUT_PATH = "input/15";


const Parsed = struct {
    warehouse: Warehouse,
    moves: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.warehouse.deinit();
        self.allocator.free(self.moves);
    }
};

const Warehouse = struct {
    area: [][]u8,
    robot_start: [2]usize,
    allocator: Allocator,

    const Self = @This();

    fn clone(self: *const Self) !Self {
        const area = try self.allocator.alloc([]u8, self.area.len);
        for (area, self.area) |*dst, src| {
            dst.* = try self.allocator.dupe(u8, src);
        }

        return .{
            .area = area,
            .robot_start = self.robot_start,
            .allocator = self.allocator,
        };
    }

    fn cloneWide(self: *const Self) !Self {
        const area = try self.allocator.alloc([]u8, self.area.len);
        for (area, self.area) |*dst, src| {
            dst.* = try self.allocator.alloc(u8, src.len << 1);
            var i: usize = 0;
            while (i < src.len << 1) : (i += 2) {
                switch (src[i >> 1]) {
                    '#' => {
                        dst.*[i + 0] = '#';
                        dst.*[i + 1] = '#';
                    },
                    '.' => {
                        dst.*[i + 0] = '.';
                        dst.*[i + 1] = '.';
                    },
                    'O' => {
                        dst.*[i + 0] = '[';
                        dst.*[i + 1] = ']';
                    },
                    '@' => {
                        dst.*[i + 0] = '@';
                        dst.*[i + 1] = '.';
                    },
                    else => unreachable
                }
            }
        }

        return .{
            .area = area,
            .robot_start = .{ self.robot_start[0] << 1, self.robot_start[1] },
            .allocator = self.allocator,
        };
    }

    fn deinit(self: *Self) void {
        for (self.area) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(self.area);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var area = List([]u8).init(allocator);
    var moves = List(u8).init(allocator);

    var it = split(u8, raw, "\n\n");

    const warehouse_str = it.next().?;
    var it_warehouse = tokenize(u8, warehouse_str, "\n");
    var i: usize = 0;
    var x: usize = undefined;
    var y: usize = undefined;
    while (it_warehouse.next()) |line| : (i += 1) {
        if (std.mem.indexOfScalar(u8, line, '@')) |x_found| {
            x = x_found;
            y = i;
        }
        area.append(allocator.dupe(u8, line) catch unreachable) catch unreachable;
    }

    const moves_str = it.next().?;
    var it_moves = tokenize(u8, moves_str, "\n");
    while (it_moves.next()) |line| {
        moves.appendSlice(line) catch unreachable;
    }

    return .{
        .warehouse = .{
            .area = area.toOwnedSlice() catch unreachable,
            .robot_start = .{ x, y },
            .allocator = allocator,
        },
        .moves = moves.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var warehouse = parsed.warehouse.clone() catch unreachable;
    defer warehouse.deinit();
    const moves = parsed.moves;

    for (moves) |dir| {
        _ = move(&warehouse, warehouse.robot_start, dir);
    }

    var accum: usize = 0;
    for (warehouse.area, 0..) |line, i| {
        for (line, 0..) |elem, j| {
            if (elem == 'O') accum += 100 * i + j;
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var warehouse = parsed.warehouse.cloneWide() catch unreachable;
    defer warehouse.deinit();
    const moves = parsed.moves;

    for (moves) |dir| {
        if (move2(true, &warehouse, warehouse.robot_start, dir)) {
            _ = move2(false, &warehouse, warehouse.robot_start, dir);
        }
    }

    var accum: usize = 0;
    for (warehouse.area, 0..) |line, i| {
        for (line, 0..) |elem, j| {
            if (elem == '[') accum += 100 * i + j;
        }
    }

    return accum;
}

fn move(warehouse: *Warehouse, pos: [2]usize, dir: u8) bool
{
    const x = pos[0];
    const y = pos[1];
    const elem = warehouse.area[y][x];

    var next_x = x;
    var next_y = y;
    switch (dir) {
        '^' => next_y -|= 1,
        '>' => next_x += 1,
        'v' => next_y += 1,
        '<' => next_x -|= 1,
        else => unreachable
    }

    switch (elem) {
        '#' => {
            return false;
        },
        '.' => {
            return true;
        },
        'O' => {
            if (move(warehouse, .{ next_x, next_y }, dir)) {
                warehouse.area[next_y][next_x] = 'O';
                return true;
            }
        },
        '@' => {
            if (move(warehouse, .{ next_x, next_y }, dir)) {
                warehouse.area[next_y][next_x] = '@';
                warehouse.area[y][x] = '.';
                warehouse.robot_start = .{ next_x, next_y };
                return true;
            }
        },
        else => unreachable
    }

    return false;
}

fn move2(comptime check_first: bool, warehouse: *Warehouse, pos: [2]usize, dir: u8) bool
{
    const x = pos[0];
    const y = pos[1];
    const elem = warehouse.area[y][x];

    var next_x = x;
    var next_y = y;
    switch (dir) {
        '^' => next_y -|= 1,
        '>' => next_x += 1,
        'v' => next_y += 1,
        '<' => next_x -|= 1,
        else => unreachable
    }

    switch (elem) {
        '#' => {
            return false;
        },
        '.' => {
            return true;
        },
        '[' => {
            switch (dir) {
                '^', 'v' => {
                    if (move2(check_first, warehouse, .{ next_x, next_y }, dir) and move2(check_first, warehouse, .{ next_x + 1, next_y }, dir)) {
                        if (!check_first) {
                            warehouse.area[next_y][next_x] = '[';
                            warehouse.area[next_y][next_x + 1] = ']';
                            warehouse.area[y][x + 1] = '.';
                        }
                        return true;
                    }
                },
                else => {
                    if (move2(check_first, warehouse, .{ next_x, next_y }, dir)) {
                        if (!check_first) warehouse.area[next_y][next_x] = '[';
                        return true;
                    }
                }
            }
        },
        ']' => {
            switch (dir) {
                '^', 'v' => {
                    if (move2(check_first, warehouse, .{ next_x, next_y }, dir) and move2(check_first, warehouse, .{ next_x - 1, next_y }, dir)) {
                        if (!check_first) {
                            warehouse.area[next_y][next_x] = ']';
                            warehouse.area[next_y][next_x - 1] = '[';
                            warehouse.area[y][x - 1] = '.';
                        }
                        return true;
                    }
                },
                else => {
                    if (move2(check_first, warehouse, .{ next_x, next_y }, dir)) {
                        if (!check_first) warehouse.area[next_y][next_x] = ']';
                        return true;
                    }
                }
            }
        },
        '@' => {
            if (move2(check_first, warehouse, .{ next_x, next_y }, dir)) {
                if (!check_first) {
                    warehouse.area[next_y][next_x] = '@';
                    warehouse.area[y][x] = '.';
                    warehouse.robot_start = .{ next_x, next_y };
                }
                return true;
            }
        },
        else => unreachable
    }

    return false;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 10000, 10000);
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

    try std.testing.expectEqual(@as(usize, 10092), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 9021), part2(parsed));
}