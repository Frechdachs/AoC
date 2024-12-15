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

const INPUT_PATH = "input/14";


const Parsed = struct {
    robots: []Robot,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.robots);
    }
};

const Robot = struct {
    pos: [2]isize,
    velocity: [2]isize,

    const Self = @This();

    fn step(self: *Self) void {
        const x = @mod(self.pos[0] + self.velocity[0], X);
        const y = @mod(self.pos[1] + self.velocity[1], Y);

        self.pos = .{ x, y };
    }
};

const X = 101;

const Y = 103;

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var robots = List(Robot).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |robot_str| {
        var it_robot = tokenize(u8, robot_str[2..], " ");

        const pos_str = it_robot.next().?;
        var idx = std.mem.indexOfScalar(u8, pos_str, ',').?;
        const pos_x = parseInt(isize, pos_str[0..idx], 10) catch unreachable;
        const pos_y = parseInt(isize, pos_str[idx + 1..], 10) catch unreachable;
        const velocity_str = it_robot.next().?;
        idx = std.mem.indexOfScalar(u8, velocity_str, ',').?;
        const velocity_x = parseInt(isize, velocity_str[2..idx], 10) catch unreachable;
        const velocity_y = parseInt(isize, velocity_str[idx + 1..], 10) catch unreachable;

        robots.append(.{
            .pos = .{ pos_x, pos_y },
            .velocity = .{ velocity_x, velocity_y },
        }) catch unreachable;
    }

    return .{
        .robots = robots.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const robots = parsed.allocator.dupe(Robot, parsed.robots) catch unreachable;
    defer parsed.allocator.free(robots);

    for (0..100) |_| {
        for (robots) |*robot| {
            robot.step();
        }
    }
    var q1: usize = 0;
    var q2: usize = 0;
    var q3: usize = 0;
    var q4: usize = 0;
    for (robots) |robot| {
        const mid_x = X / 2;
        const mid_y = Y / 2;
        const x = robot.pos[0];
        const y = robot.pos[1];
        if (x < mid_x and y < mid_y) {
            q1 += 1;
        } else if (x > mid_x and y < mid_y) {
            q2 += 1;
        } else if (x < mid_x and y > mid_y) {
            q3 += 1;
        } else if (x > mid_x and y > mid_y) {
            q4 += 1;
        }
    }

    return q1 * q2 * q3 * q4;
}

fn part2(parsed: Parsed) usize
{
    const robots = parsed.allocator.dupe(Robot, parsed.robots) catch unreachable;
    defer parsed.allocator.free(robots);
    const area = parsed.allocator.alloc(u8, Y * X) catch unreachable;
    defer parsed.allocator.free(area);
    @memset(area, ' ');

    var steps: usize = 1;
    outer: while (true) : (steps += 1) {
        for (robots) |*robot| {
            robot.step();
            area[@intCast(robot.pos[1] * X + robot.pos[0])] = '#';
        }

        for (robots) |robot| {
            const x: usize = @intCast(robot.pos[0]);
            const y: usize = @intCast(robot.pos[1]);
            // Assuming the border of the christmas tree image always has a width of 31
            // and a height of 33 but this is never explicitly checked
            if (x > X - 31 or y > Y - 33) continue;
            for (1..31) |i| {
                if (area[y * X + x + i] != '#') break;
            } else {
                break :outer;
            }
        }

//         // Show current area
//         print("Area {}:\n", .{ steps });
//         for (0..Y) |i| {
//             for (0..X) |j| {
//                 print("{c}", .{ area[i * X + j] });
//             }
//             print("\n", .{});
//         }
//         std.time.sleep(100000000);

        @memset(area, ' ');
    }

    return steps;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 10000, 100);
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

    try std.testing.expectEqual(@as(usize, 236628054), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 7584), part2(parsed));
}