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

const INPUT_PATH = "input/21";
const TEST_INPUT_PATH = "input/21test";


const Parsed = struct {
    monkeys: std.StringHashMap(Monkey),
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.monkeys.deinit();
    }
};

const MonkeyTag = enum { number, operation };

const Monkey = union(MonkeyTag) {
    number: isize,
    operation: Operation,

    fn yells(self: @This(), monkeys: *const std.StringHashMap(Monkey)) isize {
        switch(self) {
            .number => |number| return number,
            .operation => |operation| {
                const operator = operation.operator;
                const operand1 = monkeys.get(operation.operands[0]).?.yells(monkeys);
                const operand2 = monkeys.get(operation.operands[1]).?.yells(monkeys);
                switch (operator) {
                    .add => return operand1 + operand2,
                    .sub => return operand1 - operand2,
                    .mul => return operand1 * operand2,
                    .div => return @divTrunc(operand1, operand2),
                    .eql => return operand1 - operand2,
                }
            },
        }
    }
};

const Operation = struct {
    operator: Operator,
    operands: [2][]const u8,
};

const Operator = enum(u8) {
    add = '+',
    sub = '-',
    mul = '*',
    div = '/',
    eql = '=',
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var monkeys = std.StringHashMap(Monkey).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var monkey: Monkey = undefined;
        var it_line = split(u8, line, ": ");
        const name = it_line.next().?;
        const yell_str = it_line.rest();
        if (yell_str[0] >= '0' and yell_str[0] <= '9') {
            monkey = .{ .number = parseInt(isize, yell_str, 10) catch unreachable };
        } else {
            var it_yell = tokenize(u8, yell_str, " ");
            const operand1 = it_yell.next().?;
            const operator = it_yell.next().?[0];
            const operand2 = it_yell.rest();
            monkey = .{
                .operation = .{
                    .operator = @intToEnum(Operator, operator),
                    .operands = .{ operand1, operand2},
                }
            };
        }
        monkeys.put(name, monkey) catch unreachable;
    }

    return .{
        .monkeys = monkeys,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) isize
{
    const monkeys = parsed.monkeys;
    var accum: isize = 0;

    accum = monkeys.get("root").?.yells(&monkeys);

    return accum;
}

fn part2(parsed: Parsed) isize
{
    var monkeys = parsed.monkeys.clone() catch unreachable;
    defer monkeys.deinit();

    var root = monkeys.get("root").?;
    root.operation.operator = .eql;
    monkeys.put("root", root) catch unreachable;

    var humn = Monkey{ .number = 0};
    monkeys.put("humn", humn) catch unreachable;

    var diff = monkeys.get("root").?.yells(&monkeys);

    var i: isize = 1;
    var j: isize = 1;
    var k: isize = 1;
    while (diff != 0) {
        const last = diff;

        humn = Monkey{ .number = i };
        monkeys.put("humn", humn) catch unreachable;
        diff = monkeys.get("root").?.yells(&monkeys);

        // The sign of the difference changed
        if (last < 0 and diff > 0 or last > 0 and diff < 0) {
            j *= 2;
            k = ~k + 1;

        // This detects if the search number should be negative instead
        } else if (util.abs(diff) > util.abs(last)) {
            k = ~k + 1;
            i = k;
            j = 1;
            continue;
        }

        i += @divTrunc(i, j) * k;
    }

    return humn.number;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 100);
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
    try std.testing.expect(part1(parsed) == 152);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 301);
}