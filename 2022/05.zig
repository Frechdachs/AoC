const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const splitBackwards = std.mem.splitBackwards;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const parser = @import("parser.zig");
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const input = @embedFile("input/05");


const Parsed = struct {
    stacks: []List(u8),
    procedures: [][3]usize,
    allocator: Allocator,

    const Self = @This();

    fn deinit(self: *Self) void {
        for (self.stacks) |stack| {
            stack.deinit();
        }
        self.allocator.free(self.stacks);
        self.allocator.free(self.procedures);
    }

    fn clone(self: *const Self) !Self {
        var new_stacks = try List(List(u8)).initCapacity(self.allocator, self.stacks.len);
        errdefer new_stacks.deinit();
        for (self.stacks) |*stack| {
            new_stacks.appendAssumeCapacity(try stack.clone());
        }
        var new_procedures = try List([3]usize).initCapacity(self.allocator, self.procedures.len);
        errdefer new_stacks.deinit();
        new_procedures.appendSliceAssumeCapacity(self.procedures);

        return .{
            .stacks = new_stacks.toOwnedSlice(),
            .procedures = new_procedures.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var it = split(u8, raw, "\n\n");
    var it_stack = splitBackwards(u8, it.next().?, "\n");
    var stack_count = (it_stack.next().?.len + 1) / 4;

    var stacks = List(List(u8)).init(allocator);

    var i: usize = 0;
    while (i < stack_count) : (i += 1) stacks.append(List(u8).init(allocator)) catch unreachable;

    while (it_stack.next()) |level| {
        i = 0;
        while (i < stack_count) : (i += 1) {
            var crate = level[1 + i * 4];
            if (crate != ' ') stacks.items[i].append(crate) catch unreachable;
        }
        stacks.append(List(u8).init(allocator)) catch unreachable;
    }

    var procedures = List([3]usize).init(allocator);

    var procedures_it = tokenize(u8, it.next().?, "\n");
    while (procedures_it.next()) |line| {
        var num_it = tokenize(u8, line, "movefrt ");
        const amount = parseInt(usize, num_it.next().?, 10) catch unreachable;
        const origin = (parseInt(usize, num_it.next().?, 10) catch unreachable) - 1;
        const destination = (parseInt(usize, num_it.next().?, 10) catch unreachable) - 1;

        procedures.append(.{
            amount,
            origin,
            destination,
        }) catch unreachable;
    }

    return .{
        .stacks = stacks.toOwnedSlice(),
        .procedures = procedures.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(allocator: Allocator, inp: Parsed) []const u8
{
    const parsed = inp.clone() catch unreachable;
    const stacks = parsed.stacks;
    const procedures = parsed.procedures;

    for (procedures) |procedure| {
        var amount = procedure[0];
        const origin = procedure[1];
        const destination = procedure[2];

        while (amount > 0) : (amount -= 1) {
            stacks[destination].append(stacks[origin].pop()) catch unreachable;
        }
    }

    var result = List(u8).init(allocator);
    for (stacks) |*stack| {
        result.append(stack.popOrNull() orelse ' ') catch unreachable;
    }

    return result.toOwnedSlice();
}

fn part2(allocator: Allocator, inp: Parsed) []const u8
{
    const parsed = inp.clone() catch unreachable;
    const stacks = parsed.stacks;
    const procedures = parsed.procedures;

    for (procedures) |procedure| {
        var amount = procedure[0];
        const origin = procedure[1];
        const destination = procedure[2];


        const curr_len = stacks[origin].items.len;
        const slice = stacks[origin].items[curr_len - amount..];
        stacks[destination].appendSlice(slice) catch unreachable;
        stacks[origin].items.len -= amount;
    }

    var result = List(u8).init(allocator);
    for (stacks) |*stack| {
        result.append(stack.popOrNull() orelse ' ') catch unreachable;
    }

    return result.toOwnedSlice();
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var parsed = parseInput(arena.allocator(), input);
    const p1 = part1(arena.allocator(), parsed);
    const p2 = part2(arena.allocator(), parsed);

    print("Part1: {s}\n", .{ p1 });
    print("Part2: {s}\n", .{ p2 });

    try benchmark();
}


//
// Benchmarks and tests
//
fn benchmark() !void
{
    const allocator = std.heap.c_allocator;

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var inp: Parsed = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 1000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: []const u8 = undefined;
    var part1_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) timer.reset();
        p1 = part1(allocator, inp);
        defer allocator.free(p1);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: []const u8 = undefined;
    var part2_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) timer.reset();
        p2 = part2(allocator, inp);
        defer allocator.free(p2);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    util.printBenchmark(parse_time, part1_time, part2_time);
}