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
    cones: util.Grid(void),
    floor_y: isize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.cones.deinit();
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var cones = util.Grid(void).init(allocator);
    var floor_y: isize = std.math.minInt(isize);
    var it = tokenize(u8, raw, ", ->\n");
    while (it.next()) |_| {
        const y_str = it.next().?;
        const y = parseInt(isize, y_str, 10) catch unreachable;
        floor_y = @max(floor_y, y + 2);
    }
    it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var last: ?[2]isize = null;
        var it_line = tokenize(u8, line, ", ->");
        while (it_line.next()) |x_str| {
            const y_str = it_line.next().?;
            const next = [2]isize{
                parseInt(isize, y_str, 10) catch unreachable,
                parseInt(isize, x_str, 10) catch unreachable,
            };
            if (last) |prev| {
                const start_y = prev[0];
                const start_x = prev[1];
                const end_y = next[0];
                const end_x = next[1];
                if (start_y == end_y) {
                    var i: isize = @min(start_x, end_x);
                    while (i <= @max(start_x, end_x)) : (i += 1) {
                        cones.put(.{ start_y, i }, {}) catch unreachable;
                    }
                } else if (start_x == end_x) {
                    var i: isize = @min(start_y, end_y);
                    while (i <= @max(start_y, end_y)) : (i += 1) {
                        cones.put(.{ i, start_x }, {}) catch unreachable;
                    }
                } else {
                    unreachable;
                }
            }
            last = next;
        }
    }

    // Fill the cones from top to bottom
    var i: isize = 0;
    while (i < floor_y) : (i += 1) {
        var j = 500 - i;
        while (j <= 500 + i) : (j += 1) {
            if (cones.contains(.{ i - 1, j }) and cones.contains(.{ i - 1, j - 1 }) and cones.contains(.{ i - 1, j + 1 })) {
                cones.put(.{ i, j }, {}) catch unreachable;
            }
        }
    }

    return .{
        .cones = cones,
        .floor_y = floor_y,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var i: usize = 0;
    var cave = parsed.cones.clone() catch unreachable;
    defer cave.deinit();
    outer: while (true) : (i += 1) {
        var pos = [2]isize{ 0, 500 };
        while (true) {
            var stopped = false;
            var new_pos = [2]isize{ pos[0] + 1, pos[1] };
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
                cave.put(pos, {}) catch unreachable;
                break;
            }
        }
    }

    return i;
}

fn part2(parsed: Parsed) usize
{
    const cones = parsed.cones;
    const n = parsed.floor_y;

    return @intCast(usize, n * n) - cones.count();
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 10000);
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