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

const INPUT_PATH = "input/12";


const Parsed = struct {
    farm: Farm,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.farm.deinit();
    }
};

const Farm = struct {
    data: []u8,
    width: usize,
    height: usize,
    allocator: Allocator,

    const Self = @This();

    fn get(self: *const Self, x2: anytype, y2: anytype) u8 {
        const x: usize = @intCast(x2);
        const y: usize = @intCast(y2);
        return self.data[y * self.width + x];
    }

    fn set(self: *Self, elem: u8, x2: anytype, y2: anytype) void {
        const x: usize = @intCast(x2);
        const y: usize = @intCast(y2);
        self.data[y * self.width + x] = elem;
    }

    fn isSame(self: *const Self, elem: u8, x2: isize, y2: isize) bool {
        if (x2 < 0 or x2 >= self.width or y2 < 0 or y2 >= self.height) return false;

        const x: usize = @intCast(x2);
        const y: usize = @intCast(y2);
        return self.data[y * self.width + x] == elem;
    }

    fn getCountedMap(self: *const Self) !Self {
        const data_counted = try self.allocator.alloc(u8, self.data.len);
        @memset(data_counted, 0);

        return .{
            .data = data_counted,
            .width = self.width,
            .height = self.height,
            .allocator = self.allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var farm_data = List(u8).init(allocator);

    var it = tokenize(u8, raw, "\n");

    var width: usize = 0;
    var height: usize = 0;
    while (it.next()) |line| : (height += 1) {
        width = line.len;
        farm_data.appendSlice(line) catch unreachable;
    }

    return .{
        .farm = .{
            .data = farm_data.toOwnedSlice() catch unreachable,
            .width = width,
            .height = height,
            .allocator = allocator,
        },
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const farm = parsed.farm;
    var counted_map = farm.getCountedMap() catch unreachable;
    defer counted_map.deinit();
    var local_counted_map = farm.getCountedMap() catch unreachable;
    defer local_counted_map.deinit();

    var accum: usize = 0;
    for (0..farm.height) |y| {
        for (0..farm.width) |x| {
            if (counted_map.get(x, y) != 0) continue;
            var area: usize = 0;
            var perimeter: usize = 0;
            count(x, y, farm.get(x, y), &farm, &counted_map, &local_counted_map, &area, &perimeter);
            @memset(local_counted_map.data, 0);
            accum += area * perimeter;
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const farm = parsed.farm;
    var counted_map = farm.getCountedMap() catch unreachable;
    defer counted_map.deinit();
    var local_counted_map = farm.getCountedMap() catch unreachable;
    defer local_counted_map.deinit();

    var accum: usize = 0;
    for (0..farm.height) |y| {
        for (0..farm.width) |x| {
            if (counted_map.get(x, y) != 0) continue;
            var area: usize = 0;
            var corners: usize = 0;
            count2(@intCast(x), @intCast(y), farm.get(x, y), &farm, &counted_map, &local_counted_map, &area, &corners);
            @memset(local_counted_map.data, 0);
            accum += area * corners;
        }
    }

    return accum;
}

fn count(x: usize, y: usize, prev_plant: u8, farm: *const Farm, counted_map: *Farm,  local_counted_map: *Farm, area: *usize, perimeter: *usize) void
{
    const plant = farm.get(x, y);

    if (plant != prev_plant) {
        perimeter.* += 1;
        return;
    }

    area.* += 1;
    counted_map.set(1, x, y);
    local_counted_map.set(1, x, y);

    if (x == 0 or x == farm.width - 1) perimeter.* += 1;
    if (y == 0 or y == farm.height - 1) perimeter.* += 1;

    if (x < farm.width - 1 and local_counted_map.get(x + 1, y) == 0) count(x + 1, y, prev_plant, farm, counted_map, local_counted_map, area, perimeter);
    if (y < farm.height - 1 and local_counted_map.get(x, y + 1) == 0) count(x, y + 1, prev_plant, farm, counted_map, local_counted_map, area, perimeter);
    if (y > 0 and local_counted_map.get(x, y - 1) == 0) count(x, y - 1, prev_plant, farm, counted_map, local_counted_map, area, perimeter);
    if (x > 0 and local_counted_map.get(x - 1, y) == 0) count(x - 1, y, prev_plant, farm, counted_map, local_counted_map, area, perimeter);
}

fn count2(x: isize, y: isize, prev_plant: u8, farm: *const Farm, counted_map: *Farm, local_counted_map: *Farm, area: *usize, corners: *usize) void
{
    const plant = farm.get(x, y);

    if (plant != prev_plant) {
        return;
    }

    area.* += 1;
    counted_map.set(1, x, y);
    local_counted_map.set(1, x, y);

    const n = farm.isSame(plant, x, y - 1);
    const ne = farm.isSame(plant, x + 1, y - 1);
    const e = farm.isSame(plant, x + 1, y);
    const se = farm.isSame(plant, x + 1, y + 1);
    const s = farm.isSame(plant, x, y + 1);
    const sw = farm.isSame(plant, x - 1, y + 1);
    const w = farm.isSame(plant, x - 1, y);
    const nw = farm.isSame(plant, x - 1, y - 1);

    if (n and e and !ne) corners.* += 1;
    if (!n and !e) corners.* += 1;
    if (e and s and !se) corners.* += 1;
    if (!e and !s) corners.* += 1;
    if (s and w and !sw) corners.* += 1;
    if (!s and !w) corners.* += 1;
    if (w and n and !nw) corners.* += 1;
    if (!w and !n) corners.* += 1;

    if (x < farm.width - 1 and local_counted_map.get(x + 1, y) == 0) count2(x + 1, y, prev_plant, farm, counted_map, local_counted_map, area, corners);
    if (y < farm.height - 1 and local_counted_map.get(x, y + 1) == 0) count2(x, y + 1, prev_plant, farm, counted_map, local_counted_map, area, corners);
    if (y > 0 and local_counted_map.get(x, y - 1) == 0) count2(x, y - 1, prev_plant, farm, counted_map, local_counted_map, area, corners);
    if (x > 0 and local_counted_map.get(x - 1, y) == 0) count2(x - 1, y, prev_plant, farm, counted_map, local_counted_map, area, corners);
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

    try std.testing.expectEqual(@as(usize, 1930), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1206), part2(parsed));
}