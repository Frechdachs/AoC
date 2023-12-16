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

const INPUT_PATH = "input/15";


const L = 8;

const Parsed = struct {
    strings: [][]const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.strings);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var strings = List([]const u8).init(allocator);

    var it = tokenize(u8, raw, ",\n");

    while (it.next()) |instruction| {
        assert(instruction.len >= 3);
        assert(instruction.len < L + 1);
        assert(instruction[instruction.len - 1] == '-' or instruction[instruction.len - 2] == '=');

        strings.append(instruction) catch unreachable;
    }

    return .{
        .strings = strings.toOwnedSlice() catch unreachable,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const strings = parsed.strings;

    var accum: usize = 0;

    for (strings) |string| {
        accum += computeHash(string);
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    const strings = parsed.strings;
    var boxes: [256]List([L]u8) = .{ List([L]u8).init(parsed.allocator) } ** 256;
    defer for (boxes) |box| box.deinit();

    for (strings) |string| {
        if (string[string.len - 1] == '-') {
            const label = string[0..string.len - 1];
            const hash = computeHash(label);
            removeLensFromBox(label, &boxes[hash]);
        } else {
            const label = string[0..string.len - 2];
            const hash = computeHash(label);
            const focal_length = string[string.len - 1] - '0';
            addLensToBox(label, focal_length, &boxes[hash]);
        }
    }

    var accum: usize = 0;

    for (boxes, 1..) |box, i| {
        for (box.items, 1..) |lens, j| {
            accum += i * j * lens[lens.len - 1];
        }
    }

    return accum;
}

fn computeHash(string: []const u8) u8
{
    var hash: u8 = 0;

    for (string) |c| {
        hash = (hash +% c) *% 17;
    }

    return hash;
}

fn compareLabelEqual(label1: []const u8, label2: *const [L]u8) bool
{
    assert(label1.len < label2.len);

    var i: usize = 0;
    while (i < label1.len) : (i += 1) {
        if (label1[i] != label2[i]) return false;
    }

    // Without the following check, X and XY would compare the same
    // which can be a problem if the symbols in Y add up to 256
    return label2[i] == 0;
}

fn removeLensFromBox(label: []const u8, box: *List([L]u8)) void
{
    for (box.items, 0..) |*lens, i| {
        if (compareLabelEqual(label, lens)) {
            _ = box.orderedRemove(i);
            break;
        }
    }
}

fn addLensToBox(label: []const u8, focal_length: u8, box: *List([L]u8)) void
{
    var to_insert: [L]u8 = .{ 0 } ** L;
    @memcpy(to_insert[0..label.len], label);
    to_insert[to_insert.len - 1] = focal_length;

    for (box.items) |*lens| {
        if (compareLabelEqual(label, lens)) {
            lens.* = to_insert;
            return;
        }
    }

    box.append(to_insert) catch unreachable;
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

    try std.testing.expectEqual(@as(usize, 1320), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 145), part2(parsed));
}