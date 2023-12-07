const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.splitSequence;
const splitBackwards = std.mem.splitBackwardsSequence;
const tokenize = std.mem.tokenizeAny;
const sort = std.mem.sort;
const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;

const INPUT_PATH = "input/07";


const Parsed = struct {
    hands: List(Hand),
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.hands.deinit();
    }
};

const Hand = struct {
    cards: *const [5]u8,
    bid: usize,
    hand_type: u8,
    card_strengths: [5]u8
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var hands = List(Hand).init(allocator);

    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        var it_hand = tokenize(u8, line, " ");

        const cards = it_hand.next().?;
        const bid = parseInt(usize, it_hand.rest(), 10) catch unreachable;

        hands.append(.{
            .cards = cards[0..5],
            .bid = bid,
            .hand_type = 0,
            .card_strengths = .{ 0 } ** 5,
        }) catch unreachable;
    }

    hands.shrinkAndFree(hands.items.len);

    return .{
        .hands = hands,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var hands = parsed.hands.clone() catch unreachable;
    defer hands.deinit();

    for (hands.items) |*hand| {
        hand.hand_type = getHandType(false, hand.cards);
        for (0..5) |i| {
            hand.card_strengths[i] = getCardStrength(false, hand.cards[i]);
        }
    }

    sort(Hand, hands.items, {}, byRankAsc);

    var accum: usize = 0;

    for (hands.items, 1..) |hand, i| {
        accum += hand.bid * i;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var hands = parsed.hands.clone() catch unreachable;
    defer hands.deinit();

    for (hands.items) |*hand| {
        hand.hand_type = getHandType(true, hand.cards);
        for (0..5) |i| {
            hand.card_strengths[i] = getCardStrength(true, hand.cards[i]);
        }
    }

    sort(Hand, hands.items, {}, byRankAsc);

    var accum: usize = 0;

    for (hands.items, 1..) |hand, i| {
        accum += hand.bid * i;
    }

    return accum;
}

fn byRankAsc(_: void, a: Hand, b: Hand) bool {
    const type_a = a.hand_type;
    const type_b = b.hand_type;

    if (type_a < type_b) {
        return true;
    } else if (type_a > type_b) {
        return false;
    }

    // Use vector of 8 bytes for better mapping to hardware instructions
    const strength_vec_a: @Vector(8, u8) = a.card_strengths ++ .{ undefined } ** 3;
    const strength_vec_b: @Vector(8, u8) = b.card_strengths ++ .{ undefined } ** 3;
    const smaller_vec = strength_vec_a < strength_vec_b;
    const bigger_vec = strength_vec_a > strength_vec_b;
    const smaller_packed: u8 = @bitCast(smaller_vec);
    const bigger_packed: u8 = @bitCast(bigger_vec);

    if (@ctz(smaller_packed) < @ctz(bigger_packed)) return true;

    return false;
}

fn getHandType(comptime joker: bool, cards: *const [5]u8) u8
{
    var card_counts: [13]u8 = .{ 0 } ** 13;
    var joker_count: u8 = 0;

    for (cards) |card| {
        if (joker and card == 'J') {
            joker_count += 1;
            continue;
        }
        const idx = getCardStrength(joker, card);
        card_counts[idx] += 1;
    }

    sort(u8, &card_counts, {}, std.sort.desc(u8));

    if (joker) card_counts[0] += joker_count;

    // 6 to 0 in the following order:
    //     - Five of a kind
    //     - Four of a kind
    //     - Full house
    //     - Three of a kind
    //     - Two pair
    //     - One pair
    //     - High card
    return switch (card_counts[0]) {
        4...5 => |count| count + 1,
        3 => if (card_counts[1] == 2) 4 else 3,
        2 => if (card_counts[1] == 2) 2 else 1,
        1 => 0,
        else => unreachable
    };
}

fn getCardStrength(comptime joker: bool, card: u8) u8
{
    // '2'...'9' is mapped to 0...8 (or 1...9 if playing with the joker rule)
    return switch (card) {
        '2'...'9' => |c| c - '0' - if (joker) 1 else 2,
        'T' => if (joker) 9 else 8,
        'J' => if (joker) 0 else 9,
        'Q' => 10,
        'K' => 11,
        'A' => 12,
        else => unreachable
    };
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

    try std.testing.expectEqual(@as(usize, 6440), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 5905), part2(parsed));
}