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

const INPUT_PATH = "input/03";


const Parsed = struct {
    memory: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    return .{
        .memory = raw,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const memory = parsed.memory;

    return parseMemory(false, memory);
}

fn part2(parsed: Parsed) usize
{
    const memory = parsed.memory;

    return parseMemory(true, memory);
}

fn parseMemory(comptime allow_disable: bool, memory: []const u8) usize {
    var accum: usize = 0;
    var idx_start: usize = 0;
    var idx_end: usize = 0;
    var enabled = true;

    while (idx_start < memory.len - 6) {
        const c = memory[idx_start];

        idx_start += 1;
        switch (c) {
            'm' => {
                if (!enabled) continue;
                if (memory[idx_start] != 'u') {
                    continue;
                }
                idx_start += 1;
                if (memory[idx_start] != 'l') {
                    continue;
                }
                idx_start += 1;
                if (memory[idx_start] != '(') {
                    continue;
                }
                idx_start += 1;
                var num1: usize = 0;
                var num2: usize = 0;
                if (findNum(true, idx_start, &idx_end, memory)) {
                    num1 = parseInt(usize, memory[idx_start..idx_end], 10) catch unreachable;
                } else {
                    idx_start = idx_end;
                    continue;
                }
                idx_start = idx_end + 1;
                if (idx_start >= memory.len - 1) break;
                if (findNum(false, idx_start, &idx_end, memory)) {
                    num2 = parseInt(usize, memory[idx_start..idx_end], 10) catch unreachable;
                } else {
                    idx_start = idx_end;
                    continue;
                }
                accum += num1 * num2;
            },
            'd' => {
                if (allow_disable) {
                    if (!enabled and memory.len - idx_start >= 3) {
                        if (std.mem.eql(u8, memory[idx_start..idx_start + 3], "o()")) {
                            enabled = true;
                            idx_start += 3;
                        } else {
                        }
                    } else if (enabled and memory.len - idx_start >= 6) {
                        if (std.mem.eql(u8, memory[idx_start..idx_start + 6], "on't()")) {
                            enabled = false;
                            idx_start += 6;
                        }
                    }
                }
            },
            else => {}
        }
    }

    return accum;
}

fn findNum(comptime first_num: bool, idx_start: usize, idx_end: *usize, memory: []const u8) bool
{
    var idx = idx_start;
    var found = false;
    while (idx_start < memory.len) {
        switch (memory[idx]) {
            '0'...'9' => {
                found = true;
                idx += 1;
            },
            ',' => {
                if (first_num and found) {
                    idx_end.* = idx;
                    return true;
                } else {
                    return false;
                }
            },
            ')' => {
                if (!first_num and found) {
                    idx_end.* = idx;
                    return true;
                } else {
                    return false;
                }
            },
            else => {
                idx_end.* = idx;
                return false;
            }
        }
    }
    return false;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 1000000, 100000, 100000);
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

    try std.testing.expectEqual(@as(usize, 161), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test2", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 48), part2(parsed));
}