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

const INPUT_PATH = "input/22";
const TEST_INPUT_PATH = "input/22test";


const Parsed = struct {
    map: Map([2]isize, void),
    row_borders: [][2]isize,
    column_borders: [][2]isize,
    side_length: isize,
    instructions: []Instruction,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.map.deinit();
        self.allocator.free(self.row_borders);
        self.allocator.free(self.column_borders);
        self.allocator.free(self.instructions);
    }
};

const Turn = enum(u8) {
    right = 'R',
    left = 'L',
};

const InstructionTag = enum {
    turn,
    walk,
};

const Instruction = union(InstructionTag) {
    turn: Turn,
    walk: isize,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = Map([2]isize, void).init(allocator);
    var row_borders = List([2]isize).init(allocator);
    var column_borders = List([2]isize).init(allocator);
    var it = tokenize(u8, raw, "\n");
    var last_line: []const u8 = undefined;
    var i: isize = 0;
    outer: while (it.next()) |line| : (i += 1) {
        var j: isize = 0;
        for (line) |c| {
            if (c >= '0' and c <= '9') {
                last_line = line;
                break :outer;
            }
            if (row_borders.items.len <= i) {
                row_borders.append(.{ std.math.maxInt(isize), 0 }) catch unreachable;
            }
            if (column_borders.items.len <= j) {
                column_borders.append(.{ std.math.maxInt(isize), 0 }) catch unreachable;
            }
            if (c == '.' or c == '#') {
                row_borders.items[@intCast(usize, i)][0] = @min(row_borders.items[@intCast(usize, i)][0], j);
                row_borders.items[@intCast(usize, i)][1] = j + 1;
                column_borders.items[@intCast(usize, j)][0] = @min(column_borders.items[@intCast(usize, j)][0], i);
                column_borders.items[@intCast(usize, j)][1] = i + 1;
            }
            if (c == '#') map.put(.{ i, j }, {}) catch unreachable;
            j += 1;
        }
    }

    var side_length: isize = std.math.maxInt(isize);
    for (row_borders.items) |border| {
        side_length = @min(side_length, border[1] - border[0]);
    }

    var instructions = List(Instruction).init(allocator);
    var idx: usize = 0;
    while (idx < last_line.len) : (idx += 0) {
        var end = idx;
        while (end < last_line.len and last_line[end] >= '0' and last_line[end] <= '9') end += 1;
        const steps = parseInt(isize, last_line[idx..end], 10) catch unreachable;
        instructions.append(.{
            .walk = steps
        }) catch unreachable;
        if (end < last_line.len) {
            const direction = @intToEnum(Turn, last_line[end]);
            instructions.append(.{
                .turn = direction
            }) catch unreachable;
        }
        idx = end + 1;
    }

    return .{
        .map = map,
        .row_borders = row_borders.toOwnedSlice(),
        .column_borders = column_borders.toOwnedSlice(),
        .side_length = side_length,
        .instructions = instructions.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const map = parsed.map;
    const row_borders = parsed.row_borders;
    const column_borders = parsed.column_borders;
    const instructions = parsed.instructions;

    var dir: u2 = 0;
    var pos: [2]isize = .{ 0, row_borders[0][0] };

    for (instructions) |instruction| {
        switch (instruction) {
            .turn => |d| dir +%= switch(d) { .right => 1, .left => 3 },
            .walk => |steps| {
                var count = steps;
                while (count > 0) : (count -= 1) {
                    var inc: [2]isize = .{ 0, 0 };
                    if (dir == 3) {
                        inc = .{ -1, 0 };
                    } else if (dir == 0) {
                        inc = .{ 0, 1 };
                    } else if (dir == 1) {
                        inc = .{ 1, 0 };
                    } else if (dir == 2) {
                        inc = .{ 0, -1 };
                    } else { unreachable; }

                    const new_y = pos[0] + inc[0];
                    const new_x = pos[1] + inc[1];
                    const border_y = column_borders[@intCast(usize, pos[1])];
                    const border_x = row_borders[@intCast(usize, pos[0])];
                    const new_pos = .{
                        @mod(new_y - border_y[0], border_y[1] - border_y[0]) + border_y[0],
                        @mod(new_x - border_x[0], border_x[1] - border_x[0]) + border_x[0],
                    };

                    if (map.contains(new_pos)) break;
                    pos = new_pos;
                }
            },
        }
    }

    return @intCast(usize, (pos[0] + 1) * 1000 + (pos[1] + 1) * 4 + dir);
}

fn part2(parsed: Parsed) usize
{
    const map = parsed.map;
    const row_borders = parsed.row_borders;
    const column_borders = parsed.column_borders;
    const side_length = parsed.side_length;
    const instructions = parsed.instructions;

    var dir: u2 = 0;
    var pos: [2]isize = .{ 0, row_borders[0][0] };

    for (instructions) |instruction| {
        switch (instruction) {
            .turn => |d| dir +%= switch(d) { .right => 1, .left => 3 },
            .walk => |steps| {
                var count = steps;
                while (count > 0) : (count -= 1) {
                    var inc: [2]isize = .{ 0, 0 };
                    if (dir == 3) {
                        inc = .{ -1, 0 };
                    } else if (dir == 0) {
                        inc = .{ 0, 1 };
                    } else if (dir == 1) {
                        inc = .{ 1, 0 };
                    } else if (dir == 2) {
                        inc = .{ 0, -1 };
                    } else { unreachable; }

                    const old_dir = dir;

                    var new_y = pos[0] + inc[0];
                    var new_x = pos[1] + inc[1];
                    const border_y = column_borders[@intCast(usize, pos[1])];
                    const border_x = row_borders[@intCast(usize, pos[0])];
                    const quadrant_y = @divTrunc(pos[0], side_length);
                    const quadrant_x = @divTrunc(pos[1], side_length);
                    if (new_y >= border_y[1]) {
                        if (hasQuadrant(quadrant_y + 1, quadrant_x - 1, row_borders, column_borders, side_length)) {
                            dir = 2;
                            const rem = @rem(new_x, side_length);
                            new_y = (quadrant_y + 1) * side_length + rem;
                            new_x = (quadrant_x - 1) * side_length + side_length - 1;
                        } else if (hasQuadrant(quadrant_y + 1, quadrant_x + 1, row_borders, column_borders, side_length)) {
                            dir = 0;
                            const rem = @rem(new_x, side_length);
                            new_y = (quadrant_y + 1) * side_length + side_length - 1 - rem;
                            new_x = (quadrant_x + 1) * side_length;
                        } else if (quadrant_x == 2 and quadrant_y == 2) {
                            dir = 3;
                            const qy: isize = 1;
                            const qx: isize = 0;
                            const rem = @rem(new_x, side_length);
                            new_y = qy * side_length + side_length - 1;
                            new_x = qx * side_length + side_length - 1 - rem;
                        } else if (quadrant_y == 3 and quadrant_x == 0) {
                            // dir = dir;
                            const qy: isize = 0;
                            const qx: isize = 2;
                            const rem = @rem(new_x, side_length);
                            new_y = qy * side_length;
                            new_x = qx * side_length + rem;
                        } else { unreachable; }
                    } else if (new_y < border_y[0]) {
                        if (hasQuadrant(quadrant_y - 1, quadrant_x - 1, row_borders, column_borders, side_length)) {
                            dir = 2;
                            const rem = @rem(new_x, side_length);
                            new_y = (quadrant_y - 1) * side_length + side_length - 1 - rem;
                            new_x = (quadrant_x - 1) * side_length + side_length - 1;
                        } else if (hasQuadrant(quadrant_y - 1, quadrant_x + 1, row_borders, column_borders, side_length)) {
                            dir = 0;
                            const rem = @rem(new_x, side_length);
                            new_y = (quadrant_y - 1) * side_length + rem;
                            new_x = (quadrant_x + 1) * side_length;
                        } else if (quadrant_y == 0 and quadrant_x == 2) {
                            // dir = dir;
                            const qy: isize = 3;
                            const qx: isize = 0;
                            const rem = @rem(new_x, side_length);
                            new_y = qy * side_length + side_length - 1;
                            new_x = qx * side_length + rem;
                        } else if (quadrant_y == 0 and quadrant_x == 1) {
                            dir = 0;
                            const qy: isize = 3;
                            const qx: isize = 0;
                            const rem = @rem(new_x, side_length);
                            new_y = qy * side_length + rem;
                            new_x = qx * side_length;
                        } else { unreachable; }
                    } else if (new_x >= border_x[1]) {
                        if (hasQuadrant(quadrant_y - 1, quadrant_x + 1, row_borders, column_borders, side_length)) {
                            dir = 3;
                            const rem = @rem(new_y, side_length);
                            new_y = (quadrant_y - 1) * side_length + side_length - 1;
                            new_x = (quadrant_x + 1) * side_length + rem;
                        } else if (hasQuadrant(quadrant_y + 1, quadrant_x + 1, row_borders, column_borders, side_length)) {
                            dir = 1;
                            const rem = @rem(new_y, side_length);
                            new_y = (quadrant_y + 1) * side_length;
                            new_x = (quadrant_x + 1) * side_length + side_length - 1 - rem;
                        } else if (quadrant_y == 0 and quadrant_x == 2) {
                            dir = 2;
                            const qy: isize = 2;
                            const qx: isize = 1;
                            const rem = @rem(new_y, side_length);
                            new_y = qy * side_length + side_length - 1 - rem;
                            new_x = qx * side_length + side_length - 1;
                        }  else if (quadrant_y == 2 and quadrant_x == 1) {
                            dir = 2;
                            const qy: isize = 0;
                            const qx: isize = 2;
                            const rem = @rem(new_y, side_length);
                            new_y = qy * side_length + side_length - 1 - rem;
                            new_x = qx * side_length + side_length - 1;
                        } else { unreachable; }
                    } else if (new_x < border_x[0]) {
                        if (hasQuadrant(quadrant_y - 1, quadrant_x - 1, row_borders, column_borders, side_length)) {
                            dir = 3;
                            const rem = @rem(new_y, side_length);
                            new_y = (quadrant_y - 1) * side_length + side_length - 1;
                            new_x = (quadrant_x - 1) * side_length + side_length - 1 - rem;
                        } else if (hasQuadrant(quadrant_y + 1, quadrant_x - 1, row_borders, column_borders, side_length)) {
                            dir = 1;
                            const rem = @rem(new_y, side_length);
                            new_y = (quadrant_y + 1) * side_length;
                            new_x = (quadrant_x - 1) * side_length + rem;
                        } else if (quadrant_y == 2 and quadrant_x == 0) {
                            dir = 0;
                            const qy: isize = 0;
                            const qx: isize = 1;
                            const rem = @rem(new_y, side_length);
                            new_y = qy * side_length + side_length - 1 - rem;
                            new_x = qx * side_length;
                        } else if (quadrant_y == 3 and quadrant_x == 0) {
                            dir = 1;
                            const qy: isize = 0;
                            const qx: isize = 1;
                            const rem = @rem(new_y, side_length);
                            new_y = qy * side_length;
                            new_x = qx * side_length + rem;
                        } else if (quadrant_y == 0 and quadrant_x == 1) {
                            dir = 0;
                            const qy: isize = 2;
                            const qx: isize = 0;
                            const rem = @rem(new_y, side_length);
                            new_y = qy * side_length + side_length - 1 - rem;
                            new_x = qx * side_length;
                        } else { unreachable; }
                    }

                    const new_pos = .{ new_y, new_x };

                    if (map.contains(new_pos)) {
                        dir = old_dir;
                        break;
                    }
                    pos = new_pos;
                }
            },
        }
    }

    return @intCast(usize, (pos[0] + 1) * 1000 + (pos[1] + 1) * 4 + dir);
}

fn hasQuadrant(y: isize, x: isize, row_borders: [][2]isize, column_borders: [][2]isize, side_length: isize) bool
{
    if (y * side_length >= row_borders.len) return false;
    if (x * side_length >= column_borders.len) return false;
    if (y < 0 or x < 0) return false;
    const border_y = column_borders[@intCast(usize, x * side_length)];
    const border_x = row_borders[@intCast(usize, y * side_length)];

    return (
        y * side_length >= border_y[0] and y * side_length < border_y[1] and
        x * side_length >= border_x[0] and x * side_length < border_x[1]
    );
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 1000);
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
    try std.testing.expect(part1(parsed) == 6032);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 5031);
}