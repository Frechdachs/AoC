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

const INPUT_PATH = "input/08";
const TEST_INPUT_PATH = "input/08test";


const Parsed = struct {
    forest: Forest,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.forest.deinit();
    }
};

const Forest = struct {
    items: [][]u8,
    data: []u8,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, raw: []const u8) Self {
        var items = List([]u8).init(allocator);

        var it = tokenize(u8, raw, "\n");
        const n = it.peek().?.len;

        var data = allocator.alignedAlloc(u8, 32, n * ceilN(n, 32)) catch unreachable;
        @memset(@ptrCast([*]u8, &data[0]), 0, data.len);  // Just to make sure the padding is initialized
        var i: usize = 0;
        while (it.next()) |line| : (i += 1) {
            const idx = i * ceilN(n, 32);
            @memcpy(@ptrCast([*]u8, &data[idx]), @ptrCast([*]const u8, &line[0]), n);
            items.append(data[idx..idx + n]) catch unreachable;
        }

        return .{
            .items = items.toOwnedSlice(),
            .data = data,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.data);
        self.allocator.free(self.items);
    }
};

inline fn ceilN(x: usize, n: usize) usize
{
    assert(n > 0);
    assert(n & (n - 1) == 0);  // Is power of 2

    return (x + (n - 1)) & ~(n - 1);
}

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    return .{
        .forest = Forest.init(allocator, raw),
        .allocator = allocator,
    };
}

/// Vectorized solution for part 1
fn part1(parsed: Parsed) usize
{
    const forest = parsed.forest;
    const n = forest.items.len;
    const trees = forest.data;

    const stride = ceilN(n, 32);

    var visible = parsed.allocator.alignedAlloc(u8, 32, n * stride) catch unreachable;
    defer parsed.allocator.free(visible);

    setVisibleVertical(true, trees, visible, n, stride);

    transpose(trees, n, stride);
    transpose(visible, n, stride);

    setVisibleVertical(false, trees, visible, n, stride);

    var accum: usize = 0;
    var y: usize = 0;
    while (y < n) : (y += 1) {
        var x: usize = 0;
        while (x < n) : (x += 1) {
            accum += visible[y * stride + x];
        }
    }

    return accum;
}

fn setVisibleVertical(comptime first_pass: bool, trees: []const u8, visible: []u8, n: usize, stride: usize) void
{
    const Vec32u8 = @Vector(32, u8);

    const zeros: Vec32u8 = .{ 0 } ** 32;
    const ones: Vec32u8 = .{ 1 } ** 32;

    var x: usize = 0;
    while (x < stride) : (x += 32) {
        visible[0 * stride + x..][0..32].* = ones;

        var maxvec: Vec32u8 = .{ 0 } ** 32;
        var y: usize = 1;
        while (y < n) : (y += 1) {
            const treevec: Vec32u8 = trees[y * stride + x..][0..32].*;
            var visiblevec: Vec32u8 = if (first_pass) zeros else visible[y * stride + x..][0..32].*;
            const abovevec: Vec32u8 = trees[(y - 1) * stride + x..][0..32].*;
            maxvec = @max(maxvec, abovevec);

            visible[y * stride + x..][0..32].* = @select(u8, treevec > maxvec, ones, visiblevec);
        }

        visible[(n - 1) * stride + x..][0..32].* = ones;

        maxvec = .{ 0 } ** 32;
        y = n - 1;
        while (y > 0) : (y -= 1) {
            const treevec: Vec32u8 = trees[(y - 1) * stride + x..][0..32].*;
            var visiblevec: Vec32u8 = visible[(y - 1) * stride + x..][0..32].*;
            const belowvec: Vec32u8 = trees[y * stride + x..][0..32].*;
            maxvec = @max(maxvec, belowvec);

            visible[(y - 1) * stride + x..][0..32].* = @select(u8, treevec > maxvec, ones, visiblevec);
        }
    }
}

/// Vectorized solution for part 2
fn part2(parsed: Parsed) usize
{
    const forest = parsed.forest;
    const n = forest.items.len;
    const trees = forest.data;

    const stride = ceilN(n, 32);

    var scores = parsed.allocator.alignedAlloc(u32, 32, n * stride) catch unreachable;
    defer parsed.allocator.free(scores);

    setScoresVertical(true, trees, scores, n, stride);

    transpose(trees, n, stride);
    transpose(scores, n, stride);

    setScoresVertical(false, trees, scores, n, stride);

    var max: usize = 0;
    var y: usize = 0;
    while (y < n) : (y += 1) {
        var x: usize = 0;
        while (x < n) : (x += 1) {
            max = @max(max, scores[y * stride + x]);
        }
    }

    return max;
}

fn setScoresVertical(comptime first_pass: bool, trees: []const u8, scores: []u32, n: usize, stride: usize) void
{
    const Vec32u8 = @Vector(32, u8);
    const Vec32u32 = @Vector(32, u32);

    var y: usize = 0;
    while (y < n) : (y += 1) {
        var x: usize = 0;
        while (x < stride) : (x += 32) {
            const treevec: Vec32u8 = trees[y * stride + x..][0..32].*;
            var accum1: Vec32u8 = .{ 0 } ** 32;
            var accum2: Vec32u8 = .{ 0 } ** 32;

            var i: usize = y + 1;
            var check: @Vector(32, bool) = .{ true } ** 32;
            var maxvec: Vec32u8 = .{ 0 } ** 32;
            while (i < n) : (i += 1) {
                const incr = accum1 + @splat(32, @as(u8, 1));
                accum1 = @select(u8, check, incr, accum1);
                // Using "and" does not work for bool vectors,
                // so we use this hack with the max height of the current path
                const temp: Vec32u8 = trees[i * stride + x..][0..32].*;
                maxvec = @max(maxvec, temp);
                check = treevec > maxvec;
                // Early exit
                if (!@reduce(.Or, check)) break;
            }

            i = y;
            check = .{ true } ** 32;
            maxvec = .{ 0 } ** 32;
            while (i > 0) : (i -= 1) {
                const incr = accum2 + @splat(32, @as(u8, 1));
                const temp: Vec32u8 = trees[(i - 1) * stride + x..][0..32].*;
                accum2 = @select(u8, check, incr, accum2);
                maxvec = @max(maxvec, temp);
                check = treevec > maxvec;
                if (!@reduce(.Or, check)) break;
            }

            if (first_pass) {
                scores[y * stride + x..][0..32].* = @intCast(Vec32u32, accum1) * @intCast(Vec32u32, accum2);
            } else {
                scores[y * stride + x..][0..32].* *= @intCast(Vec32u32, accum1) * @intCast(Vec32u32, accum2);
            }
        }
    }
}

fn transpose(items: anytype, n: usize, stride: usize) void
{
    var i: usize = 0;
    while (i < n - 1) : (i += 1) {
        var j: usize = i + 1;
        while (j < n) : (j += 1) {
            std.mem.swap(@TypeOf(items[0]), &items[i * stride + j], &items[j * stride + i]);
        }
    }
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), INPUT_PATH, 1024 * 1024);

    const forest = parseInput(arena.allocator(), input);
    const p1 = part1(forest);
    const p2 = part2(forest);

    print("Part1: {}\n", .{ p1 });
    print("Part2: {}\n", .{ p2 });

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 10000);
}

// /// Non-vectorized solution for part 1
// fn part1(parsed: Parsed) usize
// {
//     var accum: usize = 0;

//     const forest = parsed.forest;
//     const trees = forest.items;
//     const height = trees.len;
//     const width = trees[0].len;

//     for (trees) |tree_line, y| {
//         for (tree_line) |tree, x| {
//             if (y == 0 or x == 0 or y == height - 1 or x == width - 1) {
//                 accum += 1;
//                 continue;
//             }

//             var i: usize = 0;
//             while (i < y) : (i += 1) {
//                 if (tree <= trees[i][x]) {
//                     break;
//                 }
//             } else {
//                 accum += 1;
//                 continue;
//             }

//             i = y + 1;
//             while (i < height) : (i += 1) {
//                 if (tree <= trees[i][x]) {
//                     break;
//                 }
//             } else {
//                 accum += 1;
//                 continue;
//             }

//             i = 0;
//             while (i < x) : (i += 1) {
//                 if (tree <= trees[y][i]) {
//                     break;
//                 }
//             } else {
//                 accum += 1;
//                 continue;
//             }

//             i = x + 1;
//             while (i < width) : (i += 1) {
//                 if (tree <= trees[y][i]) {
//                     break;
//                 }
//             } else {
//                 accum += 1;
//             }
//         }
//     }

//     return accum;
// }

// /// Non-vectorized solution for part 2
// fn part2(parsed: Parsed) usize
// {
//     var max: usize = 0;

//     const forest = parsed.forest;
//     const trees = forest.items;
//     const height = trees.len;
//     const width = trees[0].len;

//     for (trees) |tree_line, y| {
//         for (tree_line) |tree, x| {
//             var counters: [4]usize = .{ 0 } ** 4;

//             if (y == 0 or x == 0 or y == height - 1 or x == width - 1) {
//                 continue;
//             }

//             var i: usize = y + 1;
//             while (i < height) : (i += 1) {
//                 counters[0] += 1;
//                 if (tree <= trees[i][x]) break;
//             }

//             i = y;
//             while (i > 0) : (i -= 1) {
//                 counters[1] += 1;
//                 if (tree <= trees[i - 1][x]) break;
//             }

//             i = x + 1;
//             while (i < width) : (i += 1) {
//                 counters[2] += 1;
//                 if (tree <= trees[y][i]) break;
//             }

//             i = x;
//             while (i > 0) : (i -= 1) {
//                 counters[3] += 1;
//                 if (tree <= trees[y][i - 1]) break;
//             }

//             max = @max(max, counters[0] * counters[1] * counters[2] * counters[3]);
//         }
//     }

//     return max;
// }


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
    try std.testing.expect(part1(parsed) == 21);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 8);
}