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

const INPUT_PATH = "input/18";
const TEST_INPUT_PATH = "input/18test";


const Parsed = struct {
    cubes: [][3]u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.cubes);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var cubes = List([3]u8).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var it_line = tokenize(u8, line, ",");
        const x = parseInt(u8, it_line.next().?, 10) catch unreachable;
        const y = parseInt(u8, it_line.next().?, 10) catch unreachable;
        const z = parseInt(u8, it_line.next().?, 10) catch unreachable;
        cubes.append(.{ x, y, z }) catch unreachable;
    }

    return .{
        .cubes = cubes.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var cubes2 = List([3]u8).init(parsed.allocator);
    defer cubes2.deinit();
    var accum: usize = 0;

    for (parsed.cubes) |cube1| {
        var free_sides: usize = 6;
        for (cubes2.items) |cube2| {
            if (cube1[0] == cube2[0] and cube1[1] == cube2[1]) {
                if (util.absdiff(cube1[2], cube2[2]) == 1) free_sides -= 1;
            }
            if (cube1[0] == cube2[0] and cube1[2] == cube2[2]) {
                if (util.absdiff(cube1[1], cube2[1]) == 1) free_sides -= 1;
            }
            if (cube1[2] == cube2[2] and cube1[1] == cube2[1]) {
                if (util.absdiff(cube1[0], cube2[0]) == 1) free_sides -= 1;
            }
        }
        cubes2.append(cube1) catch unreachable;
        accum -= 6 - free_sides;
        accum += free_sides;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var cubes = Map([3]u8, void).init(parsed.allocator);
    defer cubes.deinit();
    var accum: usize = 0;

    var max_x: u8 = 0;
    var max_y: u8 = 0;
    var max_z: u8 = 0;
    for (parsed.cubes) |cube| {
        max_x = @max(max_x, cube[0]);
        max_y = @max(max_y, cube[1]);
        max_z = @max(max_z, cube[2]);
        cubes.put(cube, {}) catch unreachable;
        if (cube[0] == 0) accum += 1;
        if (cube[1] == 0) accum += 1;
        if (cube[2] == 0) accum += 1;
    }

    var visited = Map([3]u8, void).init(parsed.allocator);
    defer visited.deinit();
    var start_cube: [3]u8 = .{ max_x + 1, max_y + 1, max_z + 1 };

    spread(start_cube, .{ max_x, max_y, max_z }, &cubes, &visited, &accum);

    return accum;
}

fn spread(cube: [3]u8, max: [3]u8, cubes: *Map([3]u8, void), visited: *Map([3]u8, void), accum: *usize) void
{
    const x = cube[0];
    const y = cube[1];
    const z = cube[2];
    if (x > max[0] + 1 or y > max[1] + 1 or z > max[2] + 1) return;
    if (visited.contains(cube)) return;
    visited.put(cube, {}) catch unreachable;
    const new_cubes = [_][3]u8{
        .{ x, y, z + 1 },
        .{ x, y, z -| 1 },
        .{ x, y + 1, z },
        .{ x, y -| 1, z },
        .{ x + 1, y, z },
        .{ x -| 1, y, z },
    };
    for (new_cubes) |new_cube| {
        if (cubes.contains(new_cube)) {
            accum.* += 1;
            continue;
        }
        spread(new_cube, max, cubes, visited, accum);
    }
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
    try std.testing.expect(part1(parsed) == 64);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 58);
}