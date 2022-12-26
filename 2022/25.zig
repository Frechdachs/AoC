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

const INPUT_PATH = "input/25";
const TEST_INPUT_PATH = "input/25test";


const Parsed = struct {
    raw: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    return .{
        .raw = raw,
        .allocator = allocator,
    };
}

fn solve(parsed: Parsed) []const u8
{
    const raw = parsed.raw;
    var accum: isize = 0;

    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var p = std.math.pow(isize, 5, @intCast(isize, line.len));
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            p = @divExact(p, 5);
            accum += switch (line[i]) {
                '0' => 0,
                '1' => p,
                '2' => p + p,
                '-' => -p,
                '=' => -p - p,
                else => unreachable,
            };
        }
    }

    var str = List(u8).init(parsed.allocator);

    if (accum == 0) {
        str.append('0') catch unreachable;

        return str.toOwnedSlice();
    }

    while (accum != 0) {
        const mod = @mod(accum, 5);
        const d: isize = switch (mod) {
            0 => 0,
            1 => 1,
            2 => 2,
            3 => -2,
            4 => -1,
            else => unreachable,
        };
        str.append(
            switch (d) {
                0 => '0',
                1 => '1',
                2 => '2',
                -2 => '=',
                -1 => '-',
                else => unreachable,
            }
        ) catch unreachable;
        accum -= d;
        accum = @divExact(accum, 5);
    }

    std.mem.reverse(u8, str.items);

    return str.toOwnedSlice();
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), INPUT_PATH, 1024 * 1024);

    const parsed = parseInput(arena.allocator(), input);
    const solution = solve(parsed);

    print("Solution: {s}\n", .{ solution });
}


//
// Tests
//
test "Solution"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    const solution = solve(parsed);
    defer parsed.allocator.free(solution);
    try std.testing.expect(std.mem.eql(u8, solution, "2=-1=0"));
}