const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const print = std.debug.print;
const split = std.mem.split;
const splitBackwards = std.mem.splitBackwards;
const tokenize = std.mem.tokenize;
const sort = std.sort.sort;
const parseInt = std.fmt.parseInt;
const parser = @import("parser.zig");
const util = @import("util.zig");

const List = std.ArrayList;
const Map = std.AutoHashMap;
const BitSet = std.StaticBitSet;

const INPUT_PATH = "input/07";
const TEST_INPUT_PATH = "input/07test";


const Dir = struct {
    size: usize,
    parent: ?*@This(),
    children: std.StringHashMap(Dir),

    fn deinit(self: *@This()) void {
        var it = self.children.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit();
        }
        self.children.deinit();
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Dir
{
    var it = tokenize(u8, raw, "\n");
    var root: Dir = .{ .size = 0, .parent = null, .children = std.StringHashMap(Dir).init(allocator) };
    var curr_dir_ptr: *Dir = &root;
    while (it.next()) |line| {
        var it_line = tokenize(u8, line, " ");
        const first = it_line.next().?;
        switch (first[0]) {
            '$' => {
                const command = it_line.next().?;
                switch (command[0]) {
                    'c' => {
                        const dirname = it_line.next().?;
                        if (dirname[0] == '/') continue;
                        if (std.mem.eql(u8, dirname, "..")) {
                            curr_dir_ptr = curr_dir_ptr.parent.?;
                        } else {
                            const new_dir_ptr = curr_dir_ptr.children.getPtr(dirname).?;
                            curr_dir_ptr = new_dir_ptr;
                        }
                    },
                    else => continue,
                }
            },
            'd' => {
                const dirname = it_line.next().?;
                var dir: Dir = undefined;
                dir = .{ .size = 0, .parent = curr_dir_ptr, .children = std.StringHashMap(Dir).init(allocator) };
                curr_dir_ptr.children.put(dirname, dir) catch unreachable;
            },
            else => {
                const size = parseInt(usize, first, 10) catch unreachable;
                curr_dir_ptr.size += size;
                if (curr_dir_ptr.parent) |parent| {
                    propagateSize(parent, size);
                }
            },
        }
    }

    return root;
}

fn propagateSize(dir: *Dir, size: usize) void
{
    dir.size += size;

    if (dir.parent) |parent| {
        propagateSize(parent, size);
    }
}

fn part1(root: Dir) usize
{
    return countDirs(100_000, &root);
}

fn part2(root: Dir) usize
{
    const needed_space: usize = 30_000_000 - (70_000_000 - root.size);

    return findSmallest(needed_space, &root);
}

fn countDirs(comptime max_size: usize, dir: *const Dir) usize
{
    var count: usize = if (dir.size <= max_size) dir.size else 0;

    var it = dir.children.iterator();
    while (it.next()) |kv| {
        count += countDirs(max_size, kv.value_ptr);
    }

    return count;
}

fn findSmallest(min_size: usize, dir: *const Dir) usize
{
    if (dir.size < min_size) return std.math.maxInt(usize);

    var min = dir.size;

    var it = dir.children.iterator();
    while (it.next()) |kv| {
        min = @min(min, findSmallest(min_size, kv.value_ptr));
    }

    return min;
}

pub fn main() !void
{
    const allocator = std.heap.c_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), INPUT_PATH, 1024 * 1024);

    const root = parseInput(arena.allocator(), input);
    const p1 = part1(root);
    const p2 = part2(root);

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
    var inp: Dir = undefined;
    var parse_time: u64 = 0;
    var timer = try std.time.Timer.start();
    while (i < 10000 + warmup) : (i += 1) {
        if (i >= warmup) timer.reset();
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) parse_time += timer.read();
    }
    parse_time /= i - warmup;

    print("Running benchmark 2/3 ...\r", .{});

    i = 0;
    var p1: usize = undefined;
    var part1_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) timer.reset();
        p1 = part1(inp);
        if (i >= warmup) part1_time += timer.read();
    }
    part1_time /= i - warmup;

    print("Running benchmark 3/3 ...\r", .{});

    i = 0;
    var p2: usize = undefined;
    var part2_time: u64 = 0;
    while (i < 10000 + warmup) : (i += 1) {
        inp = parseInput(allocator, input);
        defer inp.deinit();
        if (i >= warmup) timer.reset();
        p2 = part2(inp);
        if (i >= warmup) part2_time += timer.read();
    }
    part2_time /= i - warmup;

    print("{}{}\r", .{ p1, p2 });  // This should prevent parts of the benchmark from being optimized away.
    util.printBenchmark(parse_time, part1_time, part2_time);
}

test "Part 1"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const inp = parseInput(arena.allocator(), input);
    try std.testing.expect(part1(inp) == 95437);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), TEST_INPUT_PATH, 1024 * 1024);

    const inp = parseInput(arena.allocator(), input);
    try std.testing.expect(part2(inp) == 24933642);
}