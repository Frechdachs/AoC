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

const INPUT_PATH = "input/10";
const TEST_INPUT_PATH = "input/10test";


const Parsed = []Instruction;

const OpCode = enum {
    noop,
    add,
};

const Instruction = union(OpCode) {
    noop: void,
    add: isize,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var parsed = List(Instruction).init(allocator);

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        if (line[0] == 'n') {
            parsed.append(Instruction{ .noop = {} }) catch unreachable;
        } else {
            parsed.append(Instruction{
                .add = parseInt(isize, line[5..], 10) catch unreachable,
            }) catch unreachable;
        }
    }

    return parsed.toOwnedSlice();
}

fn part1(parsed: Parsed) isize
{
    var accum: isize = 0;
    var cycle: usize = 1;
    var checkpoint: isize = 20;
    var register: isize = 1;

    for (parsed) |instruction| {
        switch (instruction) {
            .noop => cycle += 1,
            .add => |value| {
                cycle += 2;
                register += value;
            },
        }

        if (cycle >= checkpoint) {
            const value = if (cycle == checkpoint) register else register - instruction.add;
            accum += value * checkpoint;
            checkpoint += 40;
        }
    }

    return accum;
}

fn part2(parsed: Parsed) [40 * 6 + 7]u8
{
    var cycle: usize = 0;
    var register: isize = 1;
    var screen: [40 * 6 + 7]u8 = .{ '\n' } ** (40 * 6 + 7);

    writeCharacter(&screen, cycle, register);

    for (parsed) |instruction| {
        switch (instruction) {
            .noop => cycle += 1,
            .add => |value| {
                cycle += 1;
                writeCharacter(&screen, cycle, register);
                cycle += 1;
                register += value;
            },
        }

        writeCharacter(&screen, cycle, register);
    }

    return screen;
}

fn writeCharacter(screen: []u8, cycle: usize, register: isize) void
{
    if (cycle > 240 - 1) return;
    const pos = cycle % 40;
    const idx = cycle / 40 * 41 + cycle % 40 + 1;
    const character: u8 = if (pos >= register - 1 and pos <= register + 1) '#' else '.';
    screen[idx] = character;
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
    print("Part2: {s}\n", .{ p2 });

    try benchmark();
}


//
// Benchmarks and tests
//
fn benchmark() !void
{
    const allocator = std.heap.c_allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var parsed: Parsed = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 10000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: isize = undefined;
    var part1_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
        if (i >= warmup) timer.reset();
        p1 = part1(parsed);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: [40 * 6 + 7]u8 = undefined;
    var part2_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer allocator.free(parsed);
        if (i >= warmup) timer.reset();
        p2 = part2(parsed);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, util.sumWrapping(p2) });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(part1(parsed) == 13140);
}

const TEST_CASE = \\
    \\##..##..##..##..##..##..##..##..##..##..
    \\###...###...###...###...###...###...###.
    \\####....####....####....####....####....
    \\#####.....#####.....#####.....#####.....
    \\######......######......######......####
    \\#######.......#######.......#######.....
    \\
;

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(std.mem.eql(u8, &part2(parsed), TEST_CASE));
}