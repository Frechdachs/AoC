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

const INPUT_PATH = "input/20";
const TEST_INPUT_PATH = "input/20test";


const Parsed = struct {
    num: *LinkedNum,
    count: isize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.num.deinit();
    }
};

const LinkedNum = struct {
    value: isize,
    next: *LinkedNum,
    prev: *LinkedNum,
    start: bool = false,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, value: isize) *Self {
        const num: Self = .{
            .value = value,
            .next = undefined,
            .prev = undefined,
            .allocator = allocator,
        };
        const ptr = allocator.create(Self) catch unreachable;
        ptr.* = num;

        return ptr;
    }

    fn deinit(self: *Self) void {
        var curr = self;
        while (!curr.start) {
            curr = curr.next;
        }
        curr = curr.next;
        while(!curr.start) {
            const next = curr.next;
            curr.allocator.destroy(curr);
            curr = next;
        }
        curr.allocator.destroy(curr);
    }

    fn clone(self: *const Self) *Self {
        const start = Self.init(self.allocator, self.value);
        start.start = true;
        var curr_new = start;
        var curr_self = self;
        while (!curr_self.next.start) {
            curr_new.next = Self.init(self.allocator, curr_self.next.value);
            curr_new.next.prev = curr_new;
            curr_new = curr_new.next;
            curr_self = curr_self.next;
        }
        curr_new.next = start;
        start.prev = curr_new;

        return start;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var it = tokenize(u8, raw, "\n");
    const start = LinkedNum.init(allocator, parseInt(isize, it.next().?, 10) catch unreachable);
    start.start = true;
    var prev = start;
    var count: isize = 1;
    while (it.next()) |line| : (count += 1) {
        const curr = LinkedNum.init(allocator, parseInt(isize, line, 10) catch unreachable);
        prev.next = curr;
        curr.prev = prev;
        prev = curr;
    }
    prev.next = start;
    start.prev = prev;

    return .{
        .num = start,
        .count = count,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) isize
{
    var num = parsed.num.clone();
    defer num.deinit();
    var list = List(*LinkedNum).init(parsed.allocator);
    defer list.deinit();
    list.append(num) catch unreachable;
    num = num.next;
    while (!num.start) : (num = num.next) list.append(num) catch unreachable;
    for (list.items) |n| {
        switchNum(n, parsed.count);
    }
    num = findZero(num);
    var accum: isize = 0;
    var i: usize = 1;
    while (i < 3000 + 1) : (i += 1) {
        num = num.next;
        if (i % 1000 == 0) accum += num.value;
    }

    return accum;
}

fn part2(parsed: Parsed) isize
{
    var num = parsed.num.clone();
    defer num.deinit();
    num.value *= 811589153;
    var list = List(*LinkedNum).init(parsed.allocator);
    defer list.deinit();
    list.append(num) catch unreachable;
    num = num.next;
    while (!num.start) : (num = num.next) {
        list.append(num) catch unreachable;
        num.value *= 811589153;
    }
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        for (list.items) |n| {
            switchNum(n, parsed.count);
        }
    }
    num = findZero(num);
    var accum: isize = 0;
    i = 1;
    while (i < 3000 + 1) : (i += 1) {
        num = num.next;
        if (i % 1000 == 0) accum += num.value;
    }

    return accum;
}

fn switchNum(num: *LinkedNum, count: isize) void
{
    if (num.value == 0) return;
    if (num.value > 0) {
        var counter = @rem(num.value, count - 1);
        while (counter > 0) : (counter -= 1) {
            const prev = num.prev;
            const next = num.next;
            prev.next = next;
            next.prev = prev;
            num.prev = next;
            num.next = next.next;
            next.next = num;
            num.next.prev = num;
        }
    } else {
        var counter = @rem(num.value, count - 1);
        while (counter < 0) : (counter += 1) {
            const prev = num.prev;
            const next = num.next;
            next.prev = prev;
            prev.next = next;
            num.next = prev;
            num.prev = prev.prev;
            prev.prev = num;
            num.prev.next = num;
        }
    }

}

fn findZero(num: *LinkedNum) *LinkedNum
{
    var curr_num = num;
    while (curr_num.value != 0) {
        curr_num = curr_num.next;
    }

    return curr_num;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10, 10);
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
    try std.testing.expect(part1(parsed) == 3);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 1623178306);
}