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

const INPUT_PATH = "input/04";


const Parsed = struct {
    page: [][]const u8,
    width: usize,
    height: usize,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.page);
    }
};

const SearchElement = struct {
    delta: [2]isize,
    letter: u8,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var page = List([]const u8).init(allocator);

    const width = std.mem.indexOf(u8, raw, "\n").?;
    var it = tokenize(u8, raw, "\n");

    while (it.next()) |line| {
        page.append(line) catch unreachable;
    }
    const height = page.items.len;

    return .{
        .page = page.toOwnedSlice() catch unreachable,
        .width = width,
        .height = height,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const page = parsed.page;

    const search_words: [4][3]SearchElement = comptime (
        .{ getSearchWords(false, .{ .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } }) } ++
        .{ getSearchWords(false, .{ .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } }) } ++
        .{ getSearchWords(false, .{ .{ 1, 1 }, .{ 2, 2 }, .{ 3, 3 } }) } ++
        .{ getSearchWords(false, .{ .{ 1, -1 }, .{ 2, -2 }, .{ 3, -3 } }) }
    );
    const search_words_reverse: [4][3]SearchElement = comptime (
        .{ getSearchWords(true, .{ .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } }) } ++
        .{ getSearchWords(true, .{ .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } }) } ++
        .{ getSearchWords(true, .{ .{ 1, 1 }, .{ 2, 2 }, .{ 3, 3 } }) } ++
        .{ getSearchWords(true, .{ .{ 1, -1 }, .{ 2, -2 }, .{ 3, -3 } }) }
    );

    var accum: usize = 0;
    for (page, 0..) |line, y| {
        for (line, 0..) |letter, x| {
            switch (letter) {
                'X' => {
                    accum += searchForWord(search_words, page, parsed.width, parsed.height, x, y);
                },
                'S' => {
                    accum += searchForWord(search_words_reverse, page, parsed.width, parsed.height, x, y);
                },
                else => {}
            }
        }
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const page = parsed.page;

    var accum: usize = 0;
    for (page[1..page.len - 1], 1..) |line, y| {
        for (line[1..line.len - 1], 1..) |letter, x| {
            switch (letter) {
                'A' => {
                    if (
                        page[y - 1][x - 1] + page[y + 1][x + 1] == 'M' + 'S' and
                        page[y + 1][x - 1] + page[y - 1][x + 1] == 'M' + 'S'
                    ) accum += 1;
                },
                else => {}
            }
        }
    }

    return accum;
}

fn getSearchWords(comptime reverse: bool, comptime diff: [3][2]isize) [3]SearchElement
{
    return if (!reverse) .{
        .{ .delta = diff[0], .letter = 'M' },
        .{ .delta = diff[1], .letter = 'A' },
        .{ .delta = diff[2], .letter = 'S' },
    } else .{
        .{ .delta = diff[0], .letter = 'A' },
        .{ .delta = diff[1], .letter = 'M' },
        .{ .delta = diff[2], .letter = 'X' },
    };
}

fn searchForWord(comptime search_words: [4][3]SearchElement, page: [][]const u8, width: usize, height: usize, x: usize, y: usize) usize
{
    var accum: usize = 0;

    for (search_words) |search_word| {
        const x_last = @as(isize, @intCast(x)) + search_word[2].delta[0];
        const y_last = @as(isize, @intCast(y)) + search_word[2].delta[1];
        if (x_last < 0 or y_last < 0 or x_last >= width or y_last >= height) continue;

        var found = true;
        for (search_word) |search_element| {
            const x_next = @as(isize, @intCast(x)) + search_element.delta[0];
            const y_next = @as(isize, @intCast(y)) + search_element.delta[1];
            if (page[@intCast(y_next)][@intCast(x_next)] != search_element.letter) {
                found = false;
                break;
            }
        }
        accum += @intFromBool(found);
    }

    return accum;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 100000, 10000, 10000);
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

    try std.testing.expectEqual(@as(usize, 18), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 9), part2(parsed));
}