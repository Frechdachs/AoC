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

const INPUT_PATH = "input/06";


const Parsed = struct {
    races: []Race,
    long_race: Race,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.races);
    }
};

const Race = struct {
    time: usize,
    record: usize,
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var races = List(Race).init(allocator);

    var it = tokenize(u8, raw, "\n");

    const times = it.next().?;
    const records = it.next().?;
    var it_times = tokenize(u8, times, " ");
    var it_records = tokenize(u8, records, " ");
    _ = it_times.next().?;
    _ = it_records.next().?;
    var time_concat = List(u8).init(allocator);
    var record_concat = List(u8).init(allocator);
    defer time_concat.deinit();
    defer record_concat.deinit();

    while (it_times.next()) |time_str| {
        const record_str = it_records.next().?;
        races.append(.{
            .time = parseInt(usize, time_str, 10) catch unreachable,
            .record = parseInt(usize, record_str, 10) catch unreachable,
        }) catch unreachable;
        time_concat.appendSlice(time_str) catch unreachable;
        record_concat.appendSlice(record_str) catch unreachable;
    }

    const long_time = parseInt(usize, time_concat.items, 10) catch unreachable;
    const long_record = parseInt(usize, record_concat.items, 10) catch unreachable;

    return .{
        .races = races.toOwnedSlice() catch unreachable,
        .long_race = .{
            .time = long_time,
            .record = long_record,
        },
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const races = parsed.races;

    var prod: usize = 1;

    for (races) |race| {
        prod *= getPossibleWins(race);
    }

    return prod;
}

fn getPossibleWins(race: Race) usize
{
    // (time-x)*x > record
    // -x² + time*x > record
    // -x² + time*x - record > 0
    // x² - time*x + record < 0
    // time -> p
    // record -> q
    // x_1 = -p/2 - sqrt((p/2)² - q)
    // x_2 = -p/2 + sqrt((p/2)² - q)
    // result is the interval (x_1,x_2) (Excluding x_1 and x_2)

    const time: f64 = @floatFromInt(race.time);
    const record: f64 = @floatFromInt(race.record);

    const minus_p_half = time / 2.0;
    const sqrt = @sqrt(minus_p_half * minus_p_half - record);

    const lower: usize = @intFromFloat(@floor(minus_p_half - sqrt + 1.0));
    const upper: usize = @intFromFloat(@ceil(minus_p_half + sqrt - 1.0));

    return upper + 1 - lower;
}

fn part2(parsed: Parsed) usize
{
    const race = parsed.long_race;

    return getPossibleWins(race);
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 1000000, 1000000, 1000000);
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

    try std.testing.expectEqual(@as(usize, 288), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 71503), part2(parsed));
}