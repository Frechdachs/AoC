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

const INPUT_PATH = "input/13";


const Parsed = struct {
    claw_machines: []ClawMachine,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.claw_machines);
    }
};

const ClawMachine = struct {
    button_a: [2]i32,
    button_b: [2]i32,
    prize: [2]i64,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var claw_machines = List(ClawMachine).init(allocator);

    var it = split(u8, raw, "\n\n");

    while (it.next()) |claw_definition| {
        var it_claw = tokenize(u8, claw_definition, "\n");

        const button_a_definition = it_claw.next().?;
        const x_a = (button_a_definition[12] - '0') * 10 + (button_a_definition[13] - '0');
        const y_a = (button_a_definition[18] - '0') * 10 + (button_a_definition[19] - '0');
        const button_b_definition = it_claw.next().?;
        const x_b = (button_b_definition[12] - '0') * 10 + (button_b_definition[13] - '0');
        const y_b = (button_b_definition[18] - '0') * 10 + (button_b_definition[19] - '0');
        const prize_definition = it_claw.next().?;
        const idx = std.mem.indexOfScalar(u8, prize_definition[10..], '=').?;
        const prize_x = parseInt(i64, prize_definition[9..9 + idx - 2], 10) catch unreachable;
        const prize_y = parseInt(i64, prize_definition[10 + idx + 1..], 10) catch unreachable;

        claw_machines.append(.{
            .button_a = .{ x_a, y_a },
            .button_b = .{ x_b, y_b },
            .prize = .{ prize_x, prize_y },
        }) catch unreachable;
    }

    return .{
        .claw_machines = claw_machines.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const claw_machines = parsed.claw_machines;

    var accum: usize = 0;
    for (claw_machines) |claw_machine| {
        accum += solve(0, 100, claw_machine);
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const claw_machines = parsed.claw_machines;

    var accum: usize = 0;
    for (claw_machines) |claw_machine| {
        accum += solve(10_000_000_000_000, null, claw_machine);
    }

    return accum;
}

fn solve(comptime add: comptime_int, comptime max_presses: ?comptime_int, claw_machine: ClawMachine) usize
{
    const presses = solve2x2(.{
        .{ claw_machine.button_a[0], claw_machine.button_b[0], claw_machine.prize[0] + add },
        .{ claw_machine.button_a[1], claw_machine.button_b[1], claw_machine.prize[1] + add },
    });

    if (max_presses) |max| {
        if (presses[0] > max or presses[1] > max) return 0;
    }

    if (presses[0] < 0 or presses[1] < 0) return 0;
    if (presses[0] * claw_machine.button_a[0] + presses[1] * claw_machine.button_b[0] != claw_machine.prize[0] + add) return 0;
    if (presses[0] * claw_machine.button_a[1] + presses[1] * claw_machine.button_b[1] != claw_machine.prize[1] + add) return 0;

    const presses_a: usize = @intCast(presses[0]);
    const presses_b: usize = @intCast(presses[1]);

    return presses_a * 3 + presses_b;
}

/// Cramer's rule
inline fn solve2x2(system: [2][3]i64) [2]i64
{
    const det_m = system[0][0] * system[1][1] - system[0][1] * system[1][0];
    const a = system[0][2] * system[1][1] - system[0][1] * system[1][2];
    const b = system[0][0] * system[1][2] - system[0][2] * system[1][0];

    return .{
        @divTrunc(a, det_m),
        @divTrunc(b, det_m),
    };
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 1000000, 1000000);
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

    try std.testing.expectEqual(@as(usize, 480), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 875318608908), part2(parsed));
}