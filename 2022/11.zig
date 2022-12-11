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

const INPUT_PATH = "input/11";
const TEST_INPUT_PATH = "input/11test";


const Parsed = struct {
    monkeys: []Monkey,
    counters: []usize,
    allocator: Allocator,

    const Self = @This();

    fn deinit(self: *Self) void {
        for (self.monkeys) |*monkey| {
            monkey.deinit();
        }

        self.allocator.free(self.monkeys);
        self.allocator.free(self.counters);
    }

    fn clone(self: *const Self) !Self {
        var monkeys = try List(Monkey).initCapacity(self.allocator, self.monkeys.len);
        for (self.monkeys) |*monkey| {
            monkeys.appendAssumeCapacity(try monkey.clone());
        }
        var counters = try List(usize).initCapacity(self.allocator, self.counters.len);
        counters.appendSliceAssumeCapacity(self.counters);

        return .{
            .monkeys = monkeys.toOwnedSlice(),
            .counters = counters.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }
};

const OpCode = enum {
    square,
    add,
    mul,
};

const Operation = union(OpCode) {
    add: usize,
    mul: usize,
    square: void,
};

const Monkey = struct {
    things: List(usize),
    operation: Operation,
    divider: usize,
    next: [2]usize,

    const Self = @This();

    fn init(allocator: Allocator, raw: []const u8) Self {
        var it_monkey = tokenize(u8, raw, "\n");
        _ = it_monkey.next();

        var line = it_monkey.next().?;
        var it_items = tokenize(u8, line, " ,Staringems:");
        var things = List(usize).init(allocator);
        while (it_items.next()) |num| {
            const item = parseInt(usize, num, 10) catch unreachable;
            things.append(item) catch unreachable;
        }

        line = it_monkey.next().?;
        const operation: Operation = blk: {
            if (line[25] == 'o') {
                break :blk Operation{ .square = {} };
            } else {
                var it_op = splitBackwards(u8, line, " ");
                const n = parseInt(usize, it_op.next().?, 10) catch unreachable;
                if (line[23] == '+') {
                    break :blk Operation{ .add = n };
                } else {
                    break :blk Operation{ .mul = n };
                }
            }
        };

        line = it_monkey.next().?;
        var it_div = splitBackwards(u8, line, " ");
        const divider = parseInt(usize, it_div.next().?, 10) catch unreachable;

        line = it_monkey.next().?;
        var it_next_t = splitBackwards(u8, line, " ");
        line = it_monkey.next().?;
        var it_next_f = splitBackwards(u8, line, " ");
        const next: [2]usize = .{
            parseInt(usize, it_next_t.next().?, 10) catch unreachable,
            parseInt(usize, it_next_f.next().?, 10) catch unreachable,
        };

        return .{
            .things = things,
            .operation = operation,
            .divider = divider,
            .next = next,
        };
    }

    fn deinit(self: *Self) void {
        self.things.deinit();
    }

    fn clone(self: *const Self) !Self {
        var things = self.things;

        return .{
            .things = try things.clone(),
            .operation = self.operation,
            .divider = self.divider,
            .next = self.next,
        };
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var monkeys = List(Monkey).init(allocator);
    var counters = List(usize).init(allocator);

    var it = split(u8, raw, "\n\n");
    while (it.next()) |monkey_str| {
        const monkey = Monkey.init(allocator, monkey_str);
        monkeys.append(monkey) catch unreachable;
        counters.append(0) catch unreachable;
    }

    return .{
        .monkeys = monkeys.toOwnedSlice(),
        .counters = counters.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    return solve(false, 20, parsed);
}

fn part2(parsed: Parsed) usize
{
    return solve(true, 10_000, parsed);
}

fn solve(comptime solve_part2: bool, comptime round_count: usize, parsed: Parsed) usize
{
    var cloned = parsed.clone() catch unreachable;
    defer cloned.deinit();

    const monkeys = cloned.monkeys;
    const counters = cloned.counters;
    assert(monkeys.len > 1);

    var operand: usize = 3;

    if (solve_part2) {
        operand = monkeys[0].divider;
        for (monkeys[1..]) |*monkey| {
            operand *= monkey.divider;
        }
    }

    var round: usize = 0;
    while (round < round_count) : (round += 1) {
        for (monkeys) |*monkey, i| {
            var item_count = monkey.things.items.len;
            while (item_count > 0) : (item_count -= 1) {
                counters[i] += 1;

                var item = monkey.things.pop();
                switch (monkey.operation) {
                    .square => item *= item,
                    .add => |value| item += value,
                    .mul => |value| item *= value,
                }

                if (solve_part2) {
                    item %= operand;
                } else {
                    item /= operand;
                }

                if (item % monkey.divider == 0) {
                    monkeys[monkey.next[0]].things.append(item) catch unreachable;
                } else {
                    monkeys[monkey.next[1]].things.append(item) catch unreachable;
                }
            }
        }
    }

    const monkey_business = util.selectNthUnstable(counters, counters.len - 2);

    return monkey_business * counters[counters.len - 1];
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
        defer parsed.deinit();
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p1 = part1(parsed);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p2 = part2(parsed);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(part1(parsed) == 10605);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    try std.testing.expect(part2(parsed) == 2713310158);
}