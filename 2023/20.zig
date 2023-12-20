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

const INPUT_PATH = "input/20";


const Parsed = struct {
    broadcaster_idx: u8,
    child_module_idx: u8,
    parent_modules: [4]u8,
    modules: []Module,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        for (self.modules) |module| self.allocator.free(module.output_modules);
        self.allocator.free(self.modules);
    }
};

const Module = struct {
    module_type: ModuleType = .broadcaster,
    input_values: NodeSet = NodeSet.initEmpty(),
    input_modules: NodeSet = NodeSet.initEmpty(),
    output_modules: []u8 = &.{},

    const Self = @This();

    fn handleInput(self: *Self, input_idx: u8, input: u1) ?u1 {
        switch (self.module_type) {
            .broadcaster => return 0,
            .flipflop => {
                switch (input) {
                    0 => {
                        self.input_values.mask = ~self.input_values.mask;
                        return if (self.input_values.mask == 0) 0 else 1;
                    },
                    1 => return null,
                }
            },
            .conjunction => {
                switch (input) {
                    0 => self.input_values.unset(input_idx),
                    1 => self.input_values.set(input_idx),
                }
                if (self.input_values.mask & self.input_modules.mask == self.input_modules.mask) return 0;

                return 1;
            }
        }
    }
};

const ModuleType = enum {
    broadcaster,
    flipflop,
    conjunction,
};

const NodeSet = std.StaticBitSet(64);

const QueueValue = std.meta.Tuple(&.{ u8, u8, u1 });

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var modules_list = List(Module).init(allocator);
    var module_indices = std.StringHashMap(u8).init(allocator);
    defer module_indices.deinit();

    var it = tokenize(u8, raw, "\n");
    var module_count: u8 = 0;
    var broadcaster_idx: ?u8 = 0;

    while (it.next()) |line| {
        const name_end = std.mem.indexOf(u8, line[2..], " ").? + 2;
        const output_start = name_end + 4;
        var it_outputs = tokenize(u8, line[output_start..], ", ");
        var module_type: ModuleType = undefined;
        var name_start: usize = undefined;
        if (line[0] == 'b') {
            broadcaster_idx = null;
            name_start = 0;
            module_type = .broadcaster;
        } else {
            name_start = 1;
            module_type = switch (line[0]) {
                '%' => .flipflop,
                '&' => .conjunction,
                else => unreachable
            };
        }
        const name = line[name_start..name_end];
        const module_idx = module_indices.get(name) orelse blk: {
            module_indices.put(name, module_count) catch unreachable;
            if (broadcaster_idx == null) broadcaster_idx = module_count;
            module_count += 1;
            while (modules_list.items.len < module_count) {
                modules_list.append( Module{} ) catch unreachable;
            }
            break :blk module_count - 1;
        };

        var output_modules_list = List(u8).init(allocator);
        while (it_outputs.next()) |output_name| {
            const output_idx = module_indices.get(output_name) orelse blk: {
                module_indices.put(output_name, module_count) catch unreachable;
                module_count += 1;
                while (modules_list.items.len < module_count) {
                    modules_list.append( Module{} ) catch unreachable;
                }
                break :blk module_count - 1;
            };
            output_modules_list.append(output_idx) catch unreachable;
        }
        const output_modules = output_modules_list.toOwnedSlice() catch unreachable;

        modules_list.items[module_idx] = .{
            .module_type = module_type,
            .output_modules = output_modules,
        };
    }

    const modules = modules_list.toOwnedSlice() catch unreachable;

    for (modules, 0..) |module, i| {
        for (module.output_modules) |output_idx| {
            modules[output_idx].input_modules.set(i);
        }
    }

    var child_module_idx = blk: {
        const rx_idx = module_indices.get("rx") orelse break :blk 0;  // Test input doesn't contain rx
        const idx = @ctz(modules[rx_idx].input_modules.mask);
        break :blk idx;
    };
    var iter_parents = modules[child_module_idx].input_modules.iterator(.{});

    var i: usize = 0;
    var parent_modules: [4]u8 = undefined;
    while (iter_parents.next()) |parent_idx| : (i += 1) {
        parent_modules[i] = @intCast(parent_idx);
    }
    assert(i == 4 or !module_indices.contains("rx"));  // Test input doesn't contain rx

    return .{
        .broadcaster_idx = broadcaster_idx.?,
        .child_module_idx = child_module_idx,
        .parent_modules = parent_modules,
        .modules = modules,
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    const broadcaster_idx = parsed.broadcaster_idx;

    const modules = parsed.allocator.alloc(@TypeOf(parsed.modules[0]), parsed.modules.len) catch unreachable;
    defer parsed.allocator.free(modules);
    @memcpy(modules, parsed.modules);

    var low_pulses: usize = 0;
    var high_pulses: usize = 0;

    var queue = List(QueueValue).init(parsed.allocator);
    defer queue.deinit();

    for (0..1000) |_| {
        low_pulses += 1;  // button module always sends a low pulse

        queue.append(.{ broadcaster_idx, 0, 0 }) catch unreachable;

        while (queue.items.len > 0) {
            const value = queue.orderedRemove(0);
            const current_idx = value[0];
            const pulse_idx = value[1];
            const pulse = value[2];
            var to_send_maybe: ?u1 = null;

            to_send_maybe = modules[current_idx].handleInput(pulse_idx, pulse);

            if (to_send_maybe) |to_send| {
                for (modules[current_idx].output_modules) |output_idx| {
                    switch (to_send) {
                        0 => low_pulses += 1,
                        1 => high_pulses += 1,
                    }
                    queue.append(.{ output_idx, current_idx, to_send }) catch unreachable;
                }
            }
        }
    }

    return low_pulses * high_pulses;
}

fn part2(parsed: Parsed) usize
{
    const broadcaster_idx = parsed.broadcaster_idx;
    const child_module_idx = parsed.child_module_idx;
    const parent_modules = parsed.parent_modules;

    const modules = parsed.allocator.alloc(@TypeOf(parsed.modules[0]), parsed.modules.len) catch unreachable;
    defer parsed.allocator.free(modules);
    @memcpy(modules, parsed.modules);

    var queue = List(QueueValue).init(parsed.allocator);
    defer queue.deinit();

    var cycles: [4]usize = .{ 0 } ** 4;
    var is_set: [4]bool = .{ false } ** 4;

    var i: usize = 0;
    while (true) : (i += 1) {

        queue.append(.{ broadcaster_idx, 0, 0 }) catch unreachable;

        while (queue.items.len > 0) {
            const value = queue.orderedRemove(0);
            const current_idx = value[0];
            const pulse_idx = value[1];
            const pulse = value[2];
            var to_send_maybe: ?u1 = null;


            if (current_idx == child_module_idx) {
                for (0..4) |j| {
                    if (pulse_idx == parent_modules[j] and pulse == 1) {
                        if (cycles[j] == 0) cycles[j] = i + 1;
                    }
                    if (cycles[j] != 0) is_set[j] = true;
                    if (is_set[0] and is_set[1] and is_set[2] and is_set[3]) {
                        return util.lcm(cycles[3], util.lcm(cycles[2], util.lcm(cycles[0], cycles[1])));
                    }
                }
            }


            to_send_maybe = modules[current_idx].handleInput(pulse_idx, pulse);

            if (to_send_maybe) |to_send| {
                for (modules[current_idx].output_modules) |output_idx| {
                    queue.append(.{ output_idx, current_idx, to_send }) catch unreachable;
                }
            }
        }
    }

    unreachable;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 1000, 1000);
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

    try std.testing.expectEqual(@as(usize, 32000000), part1(parsed));
}

test "Part 1 (alternative)"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test2", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 11687500), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 228300182686739), part2(parsed));
}