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

const INPUT_PATH = "input/09";


const Parsed = struct {
    disk: []usize,
    disk_compressed: List(File),
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.disk);
        self.disk_compressed.deinit();
    }
};

const File = struct {
    num: usize,
    len: usize,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var disk = List(usize).init(allocator);
    var disk_compressed = List(File).init(allocator);

    var is_file = true;
    var counter: usize = 0;
    for (raw) |c| {
        if (c == '\n') break;

        const n = c - '0';
        var elem: usize = std.math.maxInt(usize);
        if (is_file) elem = counter;
        for (0..n) |_| {
            disk.append(elem) catch unreachable;
        }
        disk_compressed.append(.{ .num = elem, .len = n }) catch unreachable;
        if (is_file) counter += 1;
        is_file = !is_file;
    }

    return .{
        .disk = disk.toOwnedSlice() catch unreachable,
        .disk_compressed = disk_compressed,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var disk = parsed.allocator.alloc(usize, parsed.disk.len) catch unreachable;
    defer parsed.allocator.free(disk);
    @memcpy(disk, parsed.disk);

    var idx_l: usize = 0;
    var idx_r = disk.len - 1;

    while (true) {
        while (disk[idx_r] == std.math.maxInt(usize)) idx_r -= 1;
        while (disk[idx_l] != std.math.maxInt(usize)) idx_l += 1;
        if (idx_l >= idx_r) break;

        std.mem.swap(usize, &disk[idx_l], &disk[idx_r]);
    }

    var accum: usize = 0;
    for (disk, 0..) |elem, i| {
        if (elem == std.math.maxInt(usize)) break;
        accum += i * elem;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var disk_compressed = parsed.disk_compressed.clone() catch unreachable;
    defer disk_compressed.deinit();

    var j = disk_compressed.items.len - 1;
    while (j > 1) : (j -= 1) {
        const file = disk_compressed.items[j];
        if (file.num == std.math.maxInt(usize)) continue;
        for (disk_compressed.items[0..j], 0..) |space, i| {
            if (space.num != std.math.maxInt(usize) or space.len < file.len) continue;
            if (space.len == file.len) {
                disk_compressed.items[i] = file;
                disk_compressed.items[j] = space;
            } else {
                const diff = space.len - file.len;
                disk_compressed.items[i] = file;
                disk_compressed.items[j].num = std.math.maxInt(usize);
                disk_compressed.insert(i + 1, .{ .num = std.math.maxInt(usize), .len = diff }) catch unreachable;
            }

            break;
        }
    }

    var accum: usize = 0;
    var i: usize = 0;
    for (disk_compressed.items) |file| {
        for (0..file.len) |_| {
            if (file.num != std.math.maxInt(usize)) accum += i * file.num;
            i += 1;
        }
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10000, 100);
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

    try std.testing.expectEqual(@as(usize, 1928), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2858), part2(parsed));
}