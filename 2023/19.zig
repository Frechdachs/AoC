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

const INPUT_PATH = "input/19";


const Parsed = struct {
    workflows: std.StringHashMap(std.BoundedArray(Rule, 4)),
    parts: []Part,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.workflows.deinit();
        self.allocator.free(self.parts);
    }
};

const Part = [4]usize;

const Rule = struct {
    category: u2 = 0,
    condition: std.math.Order = .eq,
    value: usize = 0,
    destination: []const u8,

    const Self = @This();

    fn check(self: *const Self, part: Part) bool {
        return self.condition == .eq or std.math.order(part[self.category], self.value) == self.condition;
    }
};

const Range = struct {
    start: usize = 1,
    end: usize = 4000,

    const Self = @This();

    fn contains(self: *const Self, value: usize) bool {
        return value >= self.start and value <= self.end;
    }

    fn limit(self: *const Self, condition2: std.math.Order, value2: usize, complement: bool) !Self {
        var condition = condition2;
        var value = value2;

        if (complement) {
            condition = switch (condition2) {
                .gt => .lt,
                .lt => .gt,
                .eq => {
                    return error.OutOfRange;
                },
            };
            value = switch (condition2) {
                .gt => value + 1,
                .lt => value - 1,
                .eq => unreachable,
            };
        }

        switch (condition) {
            .eq => return self.*,
            .gt => {
                if (!self.contains(value + 1)) return error.OutOfRange;

                const start = @max(self.start, value + 1);
                const end = @max(self.end, value + 1);

                assert(start <= end);

                return .{ .start = start, .end = end };
            },
            .lt => {
                if (!self.contains(value - 1)) return error.OutOfRange;

                const start = @min(self.start, value - 1);
                const end = @min(self.end, value - 1);

                assert(start <= end);

                return .{ .start = start, .end = end };
            },
        }
    }

    fn count(self: *const Self) usize {
        return self.end + 1 - self.start;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var workflows = std.StringHashMap(std.BoundedArray(Rule, 4)).init(allocator);
    var parts = List(Part).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        if (line[0] != '{') {
            const idx_rules = std.mem.indexOf(u8, line, "{").?;
            const label = line[0..idx_rules];
            var it_rule = tokenize(u8, line[idx_rules + 1..line.len - 1], ",");
            var rules = std.BoundedArray(Rule, 4).init(0) catch unreachable;
            while (it_rule.next()) |rule_str| {
                const idx_dest_maybe = std.mem.indexOf(u8, rule_str, ":");
                if (idx_dest_maybe) |idx_dest| {
                    const category: u2 = switch (rule_str[0]) {
                        'x' => 0,
                        'm' => 1,
                        'a' => 2,
                        's' => 3,
                        else => unreachable
                    };
                    const condition: std.math.Order = switch (rule_str[1]) {
                        '>' => .gt,
                        '<' => .lt,
                        else => unreachable
                    };
                    const value = parseUnsigned(usize, rule_str[2..idx_dest], 10) catch unreachable;
                    const destination = rule_str[idx_dest + 1..];

                    rules.appendAssumeCapacity(.{
                        .category = category,
                        .condition = condition,
                        .value = value,
                        .destination = destination,
                    });
                } else {
                    rules.appendAssumeCapacity(.{
                        .destination = rule_str,
                    });
                }
            }
            workflows.put(label, rules) catch unreachable;
        } else {
            var part: Part = undefined;
            var it_part = tokenize(u8, line[1..line.len - 1], ",");
            inline for (0..4) |i| {
                part[i] = parseUnsigned(usize, it_part.next().?[2..], 10) catch unreachable;
            }
            parts.append(part) catch unreachable;
        }
    }

    return .{
        .workflows = workflows,
        .parts = parts.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const workflows = parsed.workflows;
    const parts = parsed.parts;

    var accum: usize = 0;

    next_part: for (parts) |part| {
        var label: []const u8 = "in";

        next_workflow: while (true) {
            const rules = workflows.get(label).?;

            next_rule: for (rules.slice()) |rule| {
                if (!rule.check(part)) continue :next_rule;

                switch (rule.destination[0]) {
                    'A' => {
                        accum += @reduce(.Add, @as(@Vector(4, usize), part));
                        continue :next_part;
                    },
                    'R' => {
                        continue :next_part;
                    },
                    else => {
                        label = rule.destination;
                        continue :next_workflow;
                    }
                }
            }
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const workflows = parsed.workflows;

    var accum: usize = 0;

    const ranges_start = [_]Range{ Range{} } ** 4;
    applyRules("in", ranges_start, &workflows, &accum);

    return accum;
}

fn applyRules(label: []const u8, ranges_start: [4]Range, workflows: *const std.StringHashMap(std.BoundedArray(Rule, 4)), accum: *usize) void
{
    const rules = workflows.get(label).?;

    var ranges_last = ranges_start;
    for (rules.slice(), 0..) |rule, i| {
        var ranges = ranges_last;
        if (i < rules.slice().len - 1) {
            ranges_last[rule.category] = ranges_last[rule.category].limit(rule.condition, rule.value, true) catch unreachable;
        }
        ranges[rule.category] = ranges[rule.category].limit(rule.condition, rule.value, false) catch {
            continue;
        };

        switch (rule.destination[0]) {
            'A' => accum.* += ranges[0].count() * ranges[1].count() * ranges[2].count() * ranges[3].count(),
            'R' => {},
            else => applyRules(rule.destination, ranges, workflows, accum)
        }
    }
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 100000, 100000);
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

    try std.testing.expectEqual(@as(usize, 19114), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 167409079868000), part2(parsed));
}