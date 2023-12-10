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

const INPUT_PATH = "input/10";


const Parsed = struct {
    network: PipeNetwork,
    allocator: Allocator,

    pub fn deinit(self: *@This()) void {
        self.network.deinit();
    }
};

const PipeNetwork = struct {
    map: [][]const Pipe,
    pos: [2]usize,
    current_pipe: Pipe,
    start_pipe: Pipe,
    dir_from: Dir,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, start: [2]usize, map: [][]const Pipe) Self {
        return .{
            .map = map,
            .pos = start,
            .current_pipe = .ns,
            .start_pipe = .st,
            .dir_from = .n,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.map);
    }

    fn getPipe(self: *const Self, pos: [2]usize) Pipe {
        return self.map[pos[0]][pos[1]];
    }

    fn getLoopLength(self: *Self) usize {
        self.current_pipe = self.getPipe(self.pos);
        assert(self.current_pipe == .st);

        const start_connection1 = self.stepFromStart();
        self.dir_from = start_connection1.flip();

        var length: usize = 1;
        while (self.current_pipe != .st) : (length += 1) {
            self.step();
        }

        const start_connection2 = self.dir_from;

        self.start_pipe = Pipe.fromDirs(start_connection1, start_connection2);

        return length / 2;
    }

    fn countLoopEnclosed(self: *Self) usize {
        self.current_pipe = self.getPipe(self.pos);
        assert(self.current_pipe == .st);

        var loop = self.allocator.alloc([]bool, self.map.len) catch unreachable;
        var enclosed = self.allocator.alloc([]bool, self.map.len) catch unreachable;
        defer self.allocator.free(loop);
        defer self.allocator.free(enclosed);

        for (loop, enclosed) |*line1, *line2| {
            line1.* = self.allocator.alloc(bool, self.map[0].len) catch unreachable;
            line2.* = self.allocator.alloc(bool, self.map[0].len) catch unreachable;
            @memset(line1.*, false);
            @memset(line2.*, false);
        }
        defer for (loop, enclosed) |line1, line2| {
            self.allocator.free(line1);
            self.allocator.free(line2);
        };

        loop[self.pos[0]][self.pos[1]] = true;
        const start_connection1 = self.stepFromStart();
        self.dir_from = start_connection1.flip();

        while (self.current_pipe != .st) {
            loop[self.pos[0]][self.pos[1]] = true;
            self.step();
        }

        const start_connection2 = self.dir_from;
        self.start_pipe = Pipe.fromDirs(start_connection1, start_connection2);

        for (0..self.map[0].len) |x| {
            var inside = false;
            var prev_angle: ?Pipe = null;
            for (0..self.map.len) |y| {
                const is_loop = loop[y][x];
                var pipe = self.map[y][x];
                if (pipe == .st) pipe = self.start_pipe;
                if (is_loop) {
                    switch (pipe) {
                        .st => unreachable,
                        .gr => unreachable,
                        .ns => {},
                        .ew => inside = !inside,
                        else => {
                            if (prev_angle) |angle_pipe| {
                                switch (pipe) {
                                    .nw => if (angle_pipe == .se) { inside = !inside; },
                                    .ne => if (angle_pipe == .sw) { inside = !inside; },
                                    else => unreachable
                                }
                                prev_angle = null;
                            } else {
                                prev_angle = pipe;
                            }
                        }
                    }
                } else {
                    switch (pipe) {
                        .st => unreachable,
                        else => enclosed[y][x] = inside
                    }
                }
            }
        }

        for (0..self.map.len) |y| {
            var inside = false;
            var prev_angle: ?Pipe = null;
            for (0..self.map[0].len) |x| {
                const is_loop = loop[y][x];
                var pipe = self.map[y][x];
                if (pipe == .st) pipe = self.start_pipe;
                if (is_loop) {
                    switch (pipe) {
                        .st => unreachable,
                        .gr => unreachable,
                        .ew => {},
                        .ns => inside = !inside,
                        else => {
                            if (prev_angle) |angle_pipe| {
                                switch (pipe) {
                                    .nw => if (angle_pipe == .se) {inside = !inside;},
                                    .sw => if (angle_pipe == .ne) {inside = !inside;},
                                    else => unreachable
                                }
                                prev_angle = null;
                            } else {
                                prev_angle = pipe;
                            }
                        }
                    }
                } else {
                    switch (pipe) {
                        .st => unreachable,
                        else => enclosed[y][x] = enclosed[y][x] and inside
                    }
                }
            }
        }

        var accum: usize = 0;
        for (enclosed) |line| {
            for (line) |value| {
                accum += @intFromBool(value);
            }
        }

        return accum;
    }

    fn stepFromStart(self: *Self) Dir {
        const candidate_e = self.getPipe(.{ self.pos[0], self.pos[1] + 1 });
        switch (candidate_e) {
            .ew, .nw, .sw => {
                self.pos[1] += 1;
                self.current_pipe = candidate_e;
                return .e;
            },
            else => {}
        }
        const candidate_s = self.getPipe(.{ self.pos[0] + 1, self.pos[1] });
        switch (candidate_s) {
            .ns, .ne, .nw => {
                self.pos[0] += 1;
                self.current_pipe = candidate_s;
                return .s;
            },
            else => {}
        }
        const candidate_w = self.getPipe(.{ self.pos[0], self.pos[1] - 1 });
        switch (candidate_w) {
            .ew, .ne, .se => {
                self.pos[1] -= 1;
                self.current_pipe = candidate_w;
                return .w;
            },
            else => {}
        }
        const candidate_n = self.getPipe(.{ self.pos[0] - 1, self.pos[1] });
        switch (candidate_n) {
            .ns, .sw, .se => {
                self.pos[0] -= 1;
                self.current_pipe = candidate_n;
                return .n;
            },
            else => {}
        }
        unreachable;
    }

    fn step(self: *Self) void {
        const dir_to = self.current_pipe.nextDir(self.dir_from);
        switch (dir_to) {
            .n => self.pos[0] -= 1,
            .s => self.pos[0] += 1,
            .w => self.pos[1] -= 1,
            .e => self.pos[1] += 1,
        }
        self.current_pipe = self.getPipe(self.pos);
        self.dir_from = dir_to.flip();
    }
};

const Dir = enum(u8) {
    n,
    e,
    s,
    w,

    const Self = @This();

    fn flip(self: Self) Self {
        return switch(self) {
            .n => .s,
            .s => .n,
            .e => .w,
            .w => .e,
        };
    }
};

const Pipe = enum(u8) {
    ns = '|',
    ew = '-',
    ne = 'L',
    nw = 'J',
    sw = '7',
    se = 'F',
    gr = '.',
    st = 'S',

    const Self = @This();

    fn nextDir(self: Self, dir_from: Dir) Dir {
        return switch (self) {
            .ns => switch (dir_from) {
                .n => .s,
                .s => .n,
                else => unreachable
            },
            .ew => switch (dir_from) {
                .e => .w,
                .w => .e,
                else => unreachable
            },
            .ne => switch (dir_from) {
                .n => .e,
                .e => .n,
                else => unreachable
            },
            .nw => switch (dir_from) {
                .n => .w,
                .w => .n,
                else => unreachable
            },
            .sw => switch (dir_from) {
                .s => .w,
                .w => .s,
                else => unreachable
            },
            .se => switch (dir_from) {
                .s => .e,
                .e => .s,
                else => unreachable
            },
            else => unreachable
        };
    }

    fn isOpen(self: Self, dir: Dir) bool {
        return switch (self) {
            .ns => switch (dir) {
                .n, .s => true,
                else => false
            },
            .ew => switch (dir) {
                .e, .w => true,
                else => false
            },
            .ne => switch (dir) {
                .n, .e => true,
                else => false
            },
            .nw => switch (dir) {
                .n, .w => true,
                else => false
            },
            .sw => switch (dir) {
                .s, .w => true,
                else => false
            },
            .se => switch (dir) {
                .s, .e => true,
                else => false
            },
            else => true
        };
    }

    fn fromDirs(dir_from: Dir, dir_to: Dir) Self {
        for (std.enums.values(Self)) |v| {
            if (v.isOpen(dir_from) and v.isOpen(dir_to)) return v;
        }

        unreachable;
    }
};

fn parseInput(allocator: Allocator, raw: []const u8) Parsed
{
    var map = List([]const Pipe).init(allocator);

    var it = tokenize(u8, raw, "\n");
    var start = [_]usize{ 0, 0 };

    var y: usize = 0;
    while (it.next()) |line| : (y += 1) {
        const maybe_x = std.mem.indexOfScalar(u8, line, 'S');
        if (maybe_x) |x| start = .{ y, x };
        map.append(@ptrCast(line)) catch unreachable;
    }

    return .{
        .network = PipeNetwork.init(allocator, start, map.toOwnedSlice() catch unreachable),
        .allocator = allocator,
    };
}

fn part1(parsed: Parsed) usize
{
    var network = parsed.network;

    return network.getLoopLength();
}

fn part2(parsed: Parsed) usize
{
    var network = parsed.network;

    return network.countLoopEnclosed();
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

    try std.testing.expectEqual(@as(usize, 4), part1(parsed));
}

test "Part 2"
{
    const allocator = std.testing.allocator;
    const input = try std.fs.cwd().readFileAlloc(allocator, INPUT_PATH ++ "test2", 1024 * 1024);
    defer allocator.free(input);

    var parsed = parseInput(allocator, input);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 10), part2(parsed));
}