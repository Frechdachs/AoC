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

const INPUT_PATH = "input/14";


const Parsed = struct {
    dish: Dish,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.dish.deinit();
    }
};

const Dish = struct {
    platform: [][]Rock,
    allocator: Allocator,

    const Self = @This();

    fn deinit(self: *Self) void {
        for (self.platform) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.platform);
    }

    fn clone(self: *const Self) !Self {
        const platform_new = try self.allocator.alloc([]Rock, self.platform.len);
        for (0..self.platform.len) |y| {
            const row = try self.allocator.alloc(Rock, self.platform[0].len);
            @memcpy(row, self.platform[y]);
            platform_new[y] = row;
        }

        return .{
            .platform = platform_new,
            .allocator = self.allocator,
        };
    }

    fn tilt(self: *Self, dir: Dir) void {
        switch (dir) {
            .n => {
                var x: usize = 0;
                while (x < self.platform[0].len) : (x += 1) {
                    var y: usize = 1;
                    while (y < self.platform.len) : (y += 1) {
                        if (self.platform[y][x] == .round) {
                            self.rollRock(y, x, dir);
                        }
                    }
                }
            },
            .w => {
                var y: usize = 0;
                while (y < self.platform.len) : (y += 1) {
                    var x: usize = 1;
                    while (x < self.platform[0].len) : (x += 1) {
                        if (self.platform[y][x] == .round) {
                            self.rollRock(y, x, dir);
                        }
                    }
                }
            },
            .s => {
                var y: usize = self.platform.len - 1;
                while (y > 0) : (y -= 1) {
                    var x: usize = 0;
                    while (x < self.platform[0].len) : (x += 1) {
                        if (self.platform[y - 1][x] == .round) {
                            self.rollRock(y - 1, x, dir);
                        }
                    }
                }
            },
            .e => {
                var y: usize = 0;
                while (y < self.platform.len) : (y += 1) {
                    var x: usize = self.platform[0].len - 1;
                    while (x > 0) : (x -= 1) {
                        if (self.platform[y][x - 1] == .round) {
                            self.rollRock(y, x - 1, dir);
                        }
                    }
                }
            },
        }
    }

    fn rollRock(self: *Self, y: usize, x: usize, dir: Dir) void {
        var y_new: usize = y;
        var x_new: usize = x;

        switch (dir) {
            .n => {
                y_new = y;
                while (y_new > 0 and self.platform[y_new - 1][x] == .none) y_new -= 1;
            },
            .w => {
                x_new = x;
                while (x_new > 0 and self.platform[y][x_new - 1] == .none) x_new -= 1;
            },
            .s => {
                y_new = y;
                while (y_new < self.platform.len - 1 and self.platform[y_new + 1][x] == .none) y_new += 1;
            },
            .e => {
                x_new = x;
                while (x_new < self.platform[0].len - 1 and self.platform[y][x_new + 1] == .none) x_new += 1;
            },
        }

        self.platform[y][x] = .none;
        self.platform[y_new][x_new] = .round;
    }

    fn getLoad(self: *const Self, dir: Dir) usize {
        var accum: usize = 0;

        for (0..self.platform.len) |y| {
            for (0..self.platform[0].len) |x| {
                if (self.platform[y][x] == .round) accum += switch(dir) {
                    .n => self.platform.len - y,
                    .w => self.platform[0].len - x,
                    .s => y + 1,
                    .e => x + 1,
                };
            }
        }

        return accum;
    }

    fn createPlatformString(self: *const Self) []const u8 {
        const platform_string = self.allocator.alloc(u8, self.platform.len * self.platform[0].len) catch unreachable;

        for (self.platform, 0..) |row, i| {
            const idx = i * self.platform[0].len;
            const row_string: []const u8 = @ptrCast(row);
            @memcpy(platform_string[idx..idx + self.platform[0].len], row_string);
        }

        return platform_string;
    }
};

const Rock = enum(u8) {
    round = 'O',
    cube = '#',
    none = '.',
};

const Dir = enum {
    n,
    w,
    s,
    e,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var platform = List([]Rock).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        const row = allocator.alloc(Rock, line.len) catch unreachable;
        const line_rocks: []const Rock = @ptrCast(line);
        @memcpy(row, line_rocks);

        platform.append(row) catch unreachable;
    }

    return .{
        .dish = .{
            .platform = platform.toOwnedSlice() catch unreachable,
            .allocator = allocator,
        },
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var dish = parsed.dish.clone() catch unreachable;
    defer dish.deinit();

    dish.tilt(.n);

    return dish.getLoad(.n);
}

fn part2(parsed: Parsed) usize
{
    const cycle_limit = 1_000_000_000;

    var dish = parsed.dish.clone() catch unreachable;
    defer dish.deinit();

    var key_list = List([]const u8).init(parsed.allocator);
    defer key_list.deinit();
    var cache = std.StringHashMap(usize).init(parsed.allocator);
    defer cache.deinit();

    var i: usize = 0;
    while (i < cycle_limit) : (i += 1) {
        const platform_string = dish.createPlatformString();
        key_list.append(platform_string) catch unreachable;

        if (cache.get(platform_string)) |steps| {
            const cycles = i - steps;
            const times = (cycle_limit - i) / cycles;
            i += times * cycles;
        }
        cache.put(platform_string, i) catch unreachable;

        dish.tilt(.n);
        dish.tilt(.w);
        dish.tilt(.s);
        dish.tilt(.e);
    }

    for (key_list.items) |key| dish.allocator.free(key);

    return dish.getLoad(.n);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 100000, 100);
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

    try std.testing.expectEqual(@as(usize, 136), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 64), part2(parsed));
}