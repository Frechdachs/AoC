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

const INPUT_PATH = "input/13";
const TEST_INPUT_PATH = "input/13test";


const Parsed = struct {
    packets: []Packet,
    allocator: Allocator,

    fn deinit(self: *@This()) void {
        for (self.packets) |*p| {
            p.deinit();
        }
        self.allocator.free(self.packets);
    }
};

const Packet = struct {
    value: i8,
    packets: []Packet,
    str: []const u8,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, raw: []const u8) Self {
        var packets = List(Packet).init(allocator);
        var i: usize = 1;
        outer: while (i < raw.len - 1) {
            const c = raw[i];
            if (c == '[') {
                var counter: usize = 1;
                var j: usize = i + 1;
                while (j < raw.len - 1) : (j += 1) {
                    if (raw[j] == '[') {
                        counter += 1;
                    } else if (raw[j] == ']') {
                        counter -= 1;
                        if (counter == 0) {
                            packets.append(Packet.init(allocator, raw[i..j + 1])) catch unreachable;
                            i = j + 1;
                            continue :outer;
                        }
                    }
                }
                unreachable;
            } else if (c >= '0' and c <= '9') {
                var l = List(Packet).init(allocator);
                var value = @intCast(i8, c - '0');
                while (raw[i + 1] >= '0' and raw[i + 1] <= '9') : (i += 1) {
                    value = value * 10 + @intCast(i8, raw[i + 1] - '0');
                }
                packets.append(.{
                    .value = value,
                    .packets = l.toOwnedSlice(),
                    .str = "",
                    .allocator = allocator,
                    }) catch unreachable;
            }
            i += 1;
        }

        return .{
            .value = -1,
            .packets = packets.toOwnedSlice(),
            .str = raw,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        for (self.packets) |*p| {
            p.deinit();
        }
        self.allocator.free(self.packets);
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var packets = List(Packet).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        packets.append(Packet.init(allocator, line)) catch unreachable;
    }

    return .{
        .packets = packets.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var accum: usize = 0;
    var i: usize = 0;
    while (i + 1 < parsed.packets.len) : (i += 2) {
        const p1 = parsed.packets[i];
        const p2 = parsed.packets[i + 1];
        const check = comparePackets(p1, p2);
        if (check == .lt) accum += i / 2 + 1;
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var packets = List(Packet).init(parsed.allocator);
    defer packets.deinit();
    packets.appendSlice(parsed.packets) catch unreachable;
    var p1 = Packet.init(parsed.allocator, "[[2]]");
    defer p1.deinit();
    var p2 = Packet.init(parsed.allocator, "[[6]]");
    defer p2.deinit();
    packets.append(p1) catch unreachable;
    packets.append(p2) catch unreachable;

    sort(Packet, packets.items, {}, lessThanPackets);

    var accum: usize = 1;
    for (packets.items) |p, i| {
        if (std.mem.eql(u8, p.str, "[[2]]")) {
            accum *= i + 1;
        } else if (std.mem.eql(u8, p.str, "[[6]]")) {
            accum *= i + 1;
        }
    }

    return accum;
}

fn lessThanPackets(context: void, p1: Packet, p2: Packet) bool
{
    _ = context;

    return comparePackets(p1, p2) == .lt;
}

fn comparePackets(p1: Packet, p2: Packet) std.math.Order
{
    if (p1.packets.len == 0 and p2.packets.len == 0) {
        return std.math.order(p1.value, p2.value);

    } else if (p2.packets.len == 0) {
        var comp = p1.packets[0];
        while (comp.packets.len != 0) {
            comp = comp.packets[0];
        }
        return if (comp.value < p2.value) .lt else .gt;

    } else if (p1.packets.len == 0) {
        var comp = p2.packets[0];
        while (comp.packets.len != 0) {
            comp = comp.packets[0];
        }
        return if (p1.value <= comp.value) .lt else .gt;

    } else {
        var i: usize = 0;
        while (i < @min(p1.packets.len, p2.packets.len)) : (i += 1) {
            const check = comparePackets(p1.packets[i], p2.packets[i]);
            if (check != .eq) return check;
        }
        if (p1.packets.len == p2.packets.len) return .eq;
        return if (i < p2.packets.len) .lt else .gt;
    }
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

    try benchmark();
}


//
// Benchmarks and tests
//
fn benchmark() !void
{
    const allocator = std.heap.c_allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    print("Running benchmark 1/3 ...\r", .{});

    const warmup: u32 = 100;
    var i: u32 = 0;
    var parsed: Parsed = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 10000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p1 = part1(parsed);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 1000 + warmup) : (i += 1) {
        parsed = parseInput(allocator, input);
        defer parsed.deinit();
        if (i >= warmup) timer.reset();
        p2 = part2(parsed);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part1(parsed) == 13);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 140);
}