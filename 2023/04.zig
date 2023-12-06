const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/04";


const Parsed = struct {
    cards: []usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.cards);
    }
};

const NumSet = std.bit_set.ArrayBitSet(usize, 128);

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var cards = List(usize).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var it_card = tokenize(u8, line, ":");
        _ = it_card.next().?;

        var it_cardnums = tokenize(u8, it_card.rest(), "|");
        const left_str = it_cardnums.next().?;
        const right_str = it_cardnums.rest();

        var it_left = tokenize(u8, left_str, " ");
        var left = NumSet.initEmpty();
        while (it_left.next()) |num| {
            left.set(parseInt(usize, num, 10) catch unreachable);
        }

        var it_right = tokenize(u8, right_str, " ");
        var right = NumSet.initEmpty();
        while (it_right.next()) |num| {
            right.set(parseInt(usize, num, 10) catch unreachable);
        }

        cards.append(
            left.intersectWith(right).count()
        ) catch unreachable;
    }

    return .{
        .cards = cards.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const cards = parsed.cards;

    var accum: usize = 0;

    for (cards) |matches| {
        if (matches > 0) {
            accum += @as(usize, 1) << @intCast(matches - 1);
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const cards = parsed.cards;

    var accum: usize = 0;

    var card_counts = parsed.allocator.alloc(usize, cards.len) catch unreachable;
    defer parsed.allocator.free(card_counts);
    @memset(card_counts, 1);

    for (cards, 0..) |matches, i| {

        for (0..matches) |j| {
            card_counts[i + 1 + j] += card_counts[i];
        }

        accum += card_counts[i];
    }

    return accum;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 10000);
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

    try std.testing.expectEqual(@as(usize, 13), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 30), part2(parsed));
}