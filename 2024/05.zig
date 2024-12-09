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

const INPUT_PATH = "input/05";


const Parsed = struct {
    rules: Map(usize, List(usize)),
    updates: [][]usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        var it = self.rules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.rules.deinit();
        for (self.updates) |update| {
            self.allocator.free(update);
        }
        self.allocator.free(self.updates);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var rules = Map(usize, List(usize)).init(allocator);
    var updates = List([]usize).init(allocator);
    var it = split(u8, raw, "\n\n");
    var it_rules = tokenize(u8, it.next().?, "\n");

    while (it_rules.next()) |rule_str| {
        var it_rule = tokenize(u8, rule_str, "|");

        const precondition = parseInt(usize, it_rule.next().?, 10) catch unreachable;
        const number = parseInt(usize, it_rule.next().?, 10) catch unreachable;

        const result = rules.getOrPut(number) catch unreachable;
        if (result.found_existing) {
            result.value_ptr.append(precondition) catch unreachable;
        } else {
            var preconditions = List(usize).init(allocator);
            preconditions.append(precondition) catch unreachable;
            result.value_ptr.* = preconditions;
        }
    }

    var it_updates = tokenize(u8, it.next().?, "\n");

    while (it_updates.next()) |update_str| {
        var update = List(usize).init(allocator);
        var it_update = tokenize(u8, update_str, ",");

        while (it_update.next()) |num_str| {
            update.append(parseInt(usize, num_str, 10) catch unreachable) catch unreachable;
        }
        updates.append(update.toOwnedSlice() catch unreachable) catch unreachable;
    }

    return .{
        .rules = rules,
        .updates = updates.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const rules = parsed.rules;
    const updates = parsed.updates;

    var accum: usize = 0;
    for (updates) |update| {
        if (checkUpdate(false, parsed.allocator, rules, update, 0)) |mid_num| {
            accum += mid_num;
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const rules = parsed.rules;
    const updates = parsed.updates;

    var accum: usize = 0;
    for (updates) |update| {
        if (checkUpdate(true, parsed.allocator, rules, update, 0)) |mid_num| {
            accum += mid_num;
        }
    }

    return accum;
}

fn checkUpdate(comptime fix_update: bool, allocator: Allocator, rules: Map(usize, List(usize)), update: []const usize, depth: usize) ?usize
{
    var present = Map(usize, void).init(allocator);
    defer present.deinit();
    for (update) |num| {
        present.put(num, {}) catch unreachable;
    }
    var seen = Map(usize, void).init(allocator);
    defer seen.deinit();

    for (update, 0..) |num, i| {
        seen.put(num, {}) catch unreachable;
        const preconditions_maybe = rules.get(num);
        if (preconditions_maybe) |preconditions| {
            for (preconditions.items) |precondition| {
                if (present.contains(precondition) and !seen.contains(precondition)) {
                    if (!fix_update) return null;

                    var update_fixed = allocator.alloc(usize, update.len) catch unreachable;
                    defer allocator.free(update_fixed);
                    @memcpy(update_fixed[0..i], update[0..i]);
                    update_fixed[i] = precondition;
                    update_fixed[i + 1] = num;
                    var idx = i + 1;
                    var idx2 = i + 2;
                    while (idx2 < update_fixed.len) : ({ idx += 1; idx2 += 1; }) {
                        if (update[idx] == precondition) idx += 1;
                        update_fixed[idx2] = update[idx];
                    }

                    return checkUpdate(true, allocator, rules, update_fixed, depth + 1);
                }
            }
        }
    }

    return if (fix_update and depth == 0) null else update[update.len / 2];
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 1000);
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

    try std.testing.expectEqual(@as(usize, 143), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 123), part2(parsed));
}