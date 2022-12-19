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

const INPUT_PATH = "input/19";
const TEST_INPUT_PATH = "input/19test";


const Parsed = struct {
    blueprints: []Blueprint,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.blueprints);
    }
};

const Blueprint = struct {
    ore: Resources,
    clay: Resources,
    obsidian: Resources,
    geode: Resources,
};

const Resources = struct {
    ore: usize,
    clay: usize,
    obsidian: usize,

    const Self = @This();

    fn hasEnough(self: *const Self, other: Self) bool {
        return self.ore >= other.ore and self.clay >= other.clay and self.obsidian >= other.obsidian;
    }

    fn remove(self: *Self, other: Self) void {
        self.ore -= other.ore;
        self.clay -= other.clay;
        self.obsidian -= other.obsidian;
    }
};

const Factory = struct {
    blueprint: Blueprint,
    resources: Resources,
    resource_robots: Resources,
    geode_robots: usize,

    const Self = @This();

    fn addResources(self: *Self, resources: Resources) void {
        self.resources.ore += resources.ore;
        self.resources.clay += resources.clay;
        self.resources.obsidian += resources.obsidian;
    }

    fn buildOre(self: *Self) bool {
        if (!self.resources.hasEnough(self.blueprint.ore)) return false;
        self.resources.remove(self.blueprint.ore);
        self.resource_robots.ore += 1;

        return true;
    }

    fn buildClay(self: *Self) bool {
        if (!self.resources.hasEnough(self.blueprint.clay)) return false;
        self.resources.remove(self.blueprint.clay);
        self.resource_robots.clay += 1;

        return true;
    }

    fn buildObsidian(self: *Self) bool {
        if (!self.resources.hasEnough(self.blueprint.obsidian)) return false;
        self.resources.remove(self.blueprint.obsidian);
        self.resource_robots.obsidian += 1;

        return true;
    }

    fn buildGeode(self: *Self) bool {
        if (!self.resources.hasEnough(self.blueprint.geode)) return false;
        self.resources.remove(self.blueprint.geode);
        self.geode_robots += 1;

        return true;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var blueprints = List(Blueprint).init(allocator);
    var it = tokenize(u8, raw, "\n");
    while (it.next()) |line| {
        var it2 = split(u8, line, ": ");
        _ = it2.next();
        var it_line = tokenize(u8, it2.rest(), "Blueprint :Eachobs.ydg");
        const ore: Resources = .{
            .ore = parseInt(usize, it_line.next().?, 10) catch unreachable,
            .clay = 0,
            .obsidian = 0,
        };
        const clay: Resources = .{
            .ore = parseInt(usize, it_line.next().?, 10) catch unreachable,
            .clay = 0,
            .obsidian = 0,
        };
        const obsidian: Resources = .{
            .ore = parseInt(usize, it_line.next().?, 10) catch unreachable,
            .clay = parseInt(usize, it_line.next().?, 10) catch unreachable,
            .obsidian = 0,
        };
        const geode: Resources = .{
            .ore = parseInt(usize, it_line.next().?, 10) catch unreachable,
            .clay = 0,
            .obsidian = parseInt(usize, it_line.next().?, 10) catch unreachable,
        };
        blueprints.append(.{
            .ore = ore,
            .clay = clay,
            .obsidian = obsidian,
            .geode = geode,
        }) catch unreachable;
    }

    return .{
        .blueprints = blueprints.toOwnedSlice(),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var best_geode = Map(usize, usize).init(parsed.allocator);
    var best_obsidian = Map(usize, usize).init(parsed.allocator);
    var best_clay = Map(usize, usize).init(parsed.allocator);
    var best_ore = Map(usize, usize).init(parsed.allocator);
    defer best_geode.deinit();
    defer best_obsidian.deinit();
    defer best_clay.deinit();
    defer best_ore.deinit();

    var accum: usize = 0;

    for (parsed.blueprints) |blueprint, i| {
        best_geode.clearRetainingCapacity();
        best_obsidian.clearRetainingCapacity();
        best_clay.clearRetainingCapacity();
        best_ore.clearRetainingCapacity();
        const factory = Factory{
            .blueprint = blueprint,
            .resources = .{ .ore = 0, .clay = 0, .obsidian = 0 },
            .resource_robots = .{ .ore = 1, .clay = 0, .obsidian = 0 },
            .geode_robots = 0,
        };
        accum += (i + 1) * findMaximumGeode(factory, .{ &best_geode, &best_obsidian, &best_clay, &best_ore }, 0, 24);
    }

    return accum;
}

fn part2(parsed: Parsed) usize
{
    var best_geode = Map(usize, usize).init(parsed.allocator);
    var best_obsidian = Map(usize, usize).init(parsed.allocator);
    var best_clay = Map(usize, usize).init(parsed.allocator);
    var best_ore = Map(usize, usize).init(parsed.allocator);
    defer best_geode.deinit();
    defer best_obsidian.deinit();
    defer best_clay.deinit();
    defer best_ore.deinit();

    var accum: usize = 1;

    const end = @min(3, parsed.blueprints.len);
    for (parsed.blueprints[0..end]) |blueprint| {
        best_geode.clearRetainingCapacity();
        best_obsidian.clearRetainingCapacity();
        best_clay.clearRetainingCapacity();
        best_ore.clearRetainingCapacity();
        const factory = Factory{
            .blueprint = blueprint,
            .resources = .{ .ore = 0, .clay = 0, .obsidian = 0 },
            .resource_robots = .{ .ore = 1, .clay = 0, .obsidian = 0 },
            .geode_robots = 0,
        };
        accum *= findMaximumGeode(factory, .{ &best_geode, &best_obsidian, &best_clay, &best_ore }, 0, 32);
    }

    return accum;
}

/// The second test needs PRECISION 2
const PRECISION = 1;

fn findMaximumGeode(factory: Factory, best_robots: [4]*Map(usize, usize), score: usize, n: usize) usize
{
    var max: usize = score;
    const new_score = score + factory.geode_robots;
    const additional_resources = factory.resource_robots;

    if (n == 1) {
        return new_score;
    }

    // Try building the most important robot first.
    {
        var new_factory = factory;
        if (new_factory.buildGeode()) {
            new_factory.addResources(additional_resources);
            max = @max(max, findMaximumGeode(new_factory, best_robots, new_score, n - 1));
            return max;
        }
    }

    if (factory.geode_robots != 0) {
        const best_robot_count = best_robots[0].get(n) orelse 0;
        if (new_score > best_robot_count) {
            best_robots[0].put(n, new_score) catch unreachable;
        }
        // Allow to wait one round to build a robot
        if (new_score + PRECISION < best_robot_count) return max;

    } else if (factory.geode_robots == 0 and factory.resource_robots.obsidian != 0) {
        const best_robot_count = best_robots[1].get(n) orelse 0;
        const value = factory.resource_robots.obsidian;
        if (value > best_robot_count) {
            best_robots[1].put(n, value) catch unreachable;
        }
        // Allow to wait one round to build a robot
        if (value + PRECISION < best_robot_count) return max;

    } else if (factory.resource_robots.obsidian == 0 and factory.resource_robots.clay != 0) {
        const best_robot_count = best_robots[2].get(n) orelse 0;
        const value = factory.resource_robots.clay;
        if (value > best_robot_count) {
            best_robots[2].put(n, value) catch unreachable;
        }
        // Allow to wait one round to build a robot
        if (value + PRECISION < best_robot_count) return max;

    } else if (factory.resource_robots.clay == 0) {
        const best_robot_count = best_robots[3].get(n) orelse 0;
        const value = factory.resources.ore;
        if (value > best_robot_count) {
            best_robots[3].put(n, value) catch unreachable;
        }
        // Allow to wait one round to build a robot
        if (value + PRECISION < best_robot_count) return max;
    }

    if (factory.resource_robots.obsidian < factory.blueprint.geode.obsidian) {
        var new_factory = factory;
        if (new_factory.buildObsidian()) {
            new_factory.addResources(additional_resources);
            max = @max(max, findMaximumGeode(new_factory, best_robots, new_score, n - 1));
        }
    }

    if (factory.resource_robots.clay < factory.blueprint.obsidian.clay) {
        var new_factory = factory;
        if (new_factory.buildClay()) {
            new_factory.addResources(additional_resources);
            max = @max(max, findMaximumGeode(new_factory, best_robots, new_score, n - 1));
        }
    }

    const max_ore_costs = @max(factory.blueprint.geode.ore, @max(factory.blueprint.clay.ore, factory.blueprint.obsidian.ore));
    if (factory.resource_robots.ore < max_ore_costs) {
        var new_factory = factory;
        if (new_factory.buildOre()) {
            new_factory.addResources(additional_resources);
            max = @max(max, findMaximumGeode(new_factory, best_robots, new_score, n - 1));
        }
    }

    {
        var new_factory = factory;
        new_factory.addResources(additional_resources);
        max = @max(max, findMaximumGeode(new_factory, best_robots, new_score, n - 1));
    }

    return max;
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

    try util.benchmark(INPUT_PATH, parseInput, part1, part2, 10000, 10, 10);
}


//
// Tests
//
test "Part 1"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part1(parsed) == 33);
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, TEST_INPUT_PATH, 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();
    try std.testing.expect(part2(parsed) == 56 * 62);
}