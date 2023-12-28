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

const INPUT_PATH = "input/24";


const Parsed = struct {
    hailstones: []Hailstone,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.hailstones);
    }
};

const Hailstone = struct {
    origin: [3]f64,
    velocity: [3]f64,

    const Self = @This();

    fn intersect2D(self: *const Self, other: Self) ?[2]f64 {
        const o1 = self.origin;
        const o2 = other.origin;
        const v1 = self.velocity;
        const v2 = other.velocity;

        const x_diff = (o1[0] - o2[0]);
        const y_diff = (o2[1] - o1[1]);

        const denominator = 1 / (v2[0] * v1[1] - v1[0] * v2[1]);

        const t1 = (v2[1] * x_diff + v2[0] * y_diff) * denominator;
        const t2 = (v1[1] * x_diff + v1[0] * y_diff) * denominator;

//         if (std.math.isNan(t1)) return null;
//         if (std.math.isInf(t1)) return null;
        if (t1 < 0 or t2 < 0) return null;

        return .{ o1[0] + v1[0] * t1, o1[1] + v1[1] * t1 };
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var hailstones = List(Hailstone).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        const idx_separator = std.mem.indexOf(u8, line, "@").?;
        var it_origin = tokenize(u8, line[0..idx_separator - 1], ", ");
        var it_velocity = tokenize(u8, line[idx_separator + 2..], ", ");
        hailstones.append(.{
            .origin = [_]f64{
                parseFloat(f64, it_origin.next().?) catch unreachable,
                parseFloat(f64, it_origin.next().?) catch unreachable,
                parseFloat(f64, it_origin.rest()) catch unreachable,
            },
            .velocity = [_]f64{
                parseFloat(f64, it_velocity.next().?) catch unreachable,
                parseFloat(f64, it_velocity.next().?) catch unreachable,
                parseFloat(f64, it_velocity.rest()) catch unreachable,
            },
        }) catch unreachable;
    }

    return .{
        .hailstones = hailstones.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const hailstones = parsed.hailstones;

    var accum: usize = 0;
    const limit = .{ 200000000000000, 400000000000000 };
    for (hailstones, 0..) |h1, i| {
        for (hailstones[i + 1..]) |h2| {
            if (h1.intersect2D(h2)) |t| {
                if (t[0] >= limit[0] and t[0] <= limit[1] and t[1] >= limit[0] and t[1] <= limit[1]) accum += 1;
            }
        }
    }

    return accum;
}

const N = 10;
const M = N - 1;
const Row = [N]f64;
const Matrix = [M]Row;

fn part2(parsed: Parsed) isize
{
    // Considering (o, v) is the origin position and velocity of the stone that we seek
    // Then we need to intersect every hailstone [(o1, v1), ..., (on, vn)] with our stone at different points in time [t1, ..., tn]
    // It is enough to consider only three hailstones to get a unique solution
    // We end up with the following equations:
    //      o + v * t1 = o1 + v1 * t1
    //      o + v * t2 = o2 + v2 * t2
    //      o + v * t3 = o3 + v3 * t3
    // Those can be rearranged as follows:
    //      o - o1 = (v - v1) * -t1
    //      o - o2 = (v - v2) * -t2
    //      o - o3 = (v - v3) * -t3
    // We can see that e.g. `(o - o1) = (v - v1) * -t1` only has a solution if the vectors (o - o1) and (v - v1) are linearly dependent
    // This means that the matrix [o - o1; v - v1] has rank < 2
    // From that follows that the three 2x2 minors of this matrix will be 0
    // By computing the three minors we get three equations (terms that we can already compute with the input have been put on the rhs):
    //      -o[1]*v[0] + o[0]*v[1] + o1[1]*v[0] - o1[0]*v[1] - o[0]*v1[1] + o[1]*v1[0] = -o1[0]*v1[1] + o1[1]*v1[0]
    //      -o[2]*v[1] + o[1]*v[2] + o1[2]*v[1] - o1[1]*v[2] - o[1]*v1[2] + o[2]*v1[1] = -o1[1]*v1[2] + o1[2]*v1[1]
    //      -o[2]*v[0] + o[0]*v[2] + o1[2]*v[0] - o1[0]*v[2] - o[0]*v1[2] + o[2]*v1[0] = -o1[0]*v1[2] + o1[2]*v1[0]
    // [t1, ..., tn] can be eliminated this way from our equations
    // Then we take the non-linear terms in all three equations (-o[1]*v[0] + o[0]*v[1]), (-o[2]*v[1] + o[1]*v[2]), and (-o[2]*v[0] + o[0]*v[2])
    // and replace them with variables a, b, and c to get a linear system that can be solved with gaussian elimination
    // There are now 9 unknowns, so we need 9 equations
    // Since computing the 2x2 minors gives us three equations per hailstone,
    // we need to consider exactly three hailstones to arrive at a solution
    // We use gaussian elimination to solve this linear system for o[0], o[1], o[2], v[0], v[1], v[2], a, b, and c
    const hailstones = parsed.hailstones;

    var matrix: Matrix = .{ .{ 0 } ** N } ** M;

    for (hailstones[0..3], 0..) |h, i| {
        const o = h.origin;
        const v = h.velocity;

        const rows = [_]Row{
            //  o[0]  o[1]  o[2]  v[0]   v[1]   v[2]  a  b  c              rhs
            .{ -v[1], v[0],   0,  o[1], -o[0],    0,  1, 0, 0, -o[0] * v[1] + o[1] * v[0] },
            .{    0, -v[2], v[1],   0,   o[2], -o[1], 0, 1, 0, -o[1] * v[2] + o[2] * v[1] },
            .{ -v[2],   0,  v[0], o[2],    0,  -o[0], 0, 0, 1, -o[0] * v[2] + o[2] * v[0] },
        };
        matrix[i * 3..][0..3].* = rows;
    }

    // Gaussian elimination
    // Transform a M x (M + 1) matrix into row echelon form
    var i: usize = 0;
    var j: usize = 0;
    while (i < M and j < M) {
        var i_max = i;
        var max = @fabs(matrix[i][j]);
        for (i + 1..M) |k| {
            if (@fabs(matrix[k][j]) > max) {
                max = @fabs(matrix[k][j]);
                i_max = k;
            }
        }
        if (matrix[i_max][j] == 0) {
            j += 1;
            continue;
        }
        std.mem.swap(Row, &matrix[i], &matrix[i_max]);
        for (i + 1..M) |k| {
            const f = matrix[k][j] / matrix[i][j];
            for (j + 1..M + 1) |h| matrix[k][h] -= matrix[i][h] * f;
        }
        i += 1;
        j += 1;
    }

    // Perform back substitution on a matrix in row echelon form
    // The result will be in column (M + 1)
    i = M;
    while (i > 0) : (i -= 1) {
        j = M;
        while (j > i) : (j -= 1) {
            matrix[i - 1][M] -=  matrix[i - 1][j - 1] * matrix[j - 1][M];
        }
        matrix[i - 1][M] /= matrix[i - 1][i - 1];
    }

    var accum: isize = @intFromFloat(@round(matrix[0][M]));
    accum += @intFromFloat(@round(matrix[1][M]));
    accum += @intFromFloat(@round(matrix[2][M]));

    return accum;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 1000000);
}

//
// Tests
//
test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 16018), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(isize, 47), part2(parsed));
}