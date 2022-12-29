# Advent of Code 2022

My solutions written in Zig.

## Compilation
```
zig build-exe 01.zig -O ReleaseFast -lc
```
`-lc` will link against `libc`. I'm using the C allocator because of speed™.

As Zig is still unstable and quickly changing, the code will likely only compile with Zig `0.10.0`.

## Running tests
```
zig test 01.zig
```

## Thoughts on Zig

While Zig is still considered unstable, I'm very happy with its current state.

- Besides one thing mentioned below (day 12), I had no problems implementing my ideas that I would attribute to shortcomings of the language itself.
- Sometimes the documentation of the standard library is very sparse but the source code is easy to read.
- I think it was a very good decision to include optionals (`?T`) and error unions (`!T`) in the core language specification compared to implementing them in the standard library as for example Rust does it (i.e. `Option<T>` and `Result<T, E>`), because in my opinion it really helps readability to have short special operators when dealing with these types.
- Zig's vector type seems to be a really neat alternative to SIMD intrinsics in C.
- It's really nice to have operators for saturated addition and subtraction (`+|` and `-|`), especially when using unsigned types to prevent overflows while subtracting something from `0`.
- Generics are handled very well. Having `comptime`-known variables just as normal function arguments feels incredibly natural and completely eliminates the need for a special syntax like the turbofish in Rust.
- It's a bit annoying that Zig is still missing a range syntax.

## Thoughts on each day

Spoilers ahead.

### [Day 01]

Straightforward.

### [Day 02]

Straightforward. I made an effort to make my solution completely modulo-less and branchless (besides the obvious branching when iterating over the input).

### [Day 03]

Straightforward. As the number of possible elements was quite low, I used a BitSet instead of a HashSet for speed.

### [Day 04]

Straightforward. I implemented a custom range type and tried to minimize the number of comparisons needed for each part.

### [Day 05]

Also straightforward, as the obvious approach was basically spelled out in the title.

### [Day 06]

Straightforward again. I made it more challenging by trying to find a solution with a runtime complexity in `O(n)` instead of `O(n*m)` with `n` being the input length and `m` being the marker length.

### [Day 07]

First day that took more than just a few lines of code. Solved it with a recursive data structure, basically a tree.

### [Day 08]

My background in image processing made this task fairly easy. I manually vectorized my solution which led to an immense speed improvement. The Zig vector type makes manual vectorization a lot less annoying compared to using SIMD intrinsics in C.

### [Day 09]

Interesting problem, but still straightforward to implement. I made sure that my solution works for an arbitrary amount of knots.

### [Day 10]

This day was this year's abstract machine simulation. I usually find those days boring, but part 2 had an interesting twist in that it wrote the solution to a simulated screen.

### [Day 11]

First appearance of the monkeys. Part 2 of this day required a bit of thinking. Doing it naively would result in integers too big to be stored in common integer types. The challenge was reducing the size of individual results of multiplication or addition while preserving certain mathematical properties, in this case divisibility to certain dividers. I achived this by multiplying all dividers and using them as the RHS of a modulo operation to keep the numbers low. Given the fact that all dividers happen to be prime, this also results in the lowest possible modulo.

### [Day 12]

This year's first pathfinding problem. Solved it with Dijkstra. I experienced some strange results while debugging my Dijkstra implementation which turned out to be a [bug](https://github.com/ziglang/zig/pull/13908) in Zig's standard library.

### [Day 13]

Every year has a problem like this: parsing matching parentheses. Always annoying to implement. I did it recursively while passing a mutable index to the current position.

### [Day 14]

I really liked this task. I optimized part 2 by basically reversing the problem. I determine how many places are inaccessible to sand by computing "cones" below the walls and substract this value from the maximum possible amount of sand given the absence of walls.

### [Day 15]

Beginning with day 15, the problems became a bit harder. I solved part 1 by merging ranges. Part 2 takes too long if done naively. There are shortcuts you can implement to make the brute-force approach computable (like jumping over the range of a scanner in one dimension while iterating normally over the other), but instead I intersect the sides of each pair of rhombi (radii of the scanners) and look at the coordinates right next to the intersection point as a potential candidate which is then checked if it is outside the radius of every scanner. This reduces the problem space to just the number of scanners which is very low. The intersections are done exclusively with discrete maths.

### [Day 16]

A classic optimization problem. DFS was the way to go because the recursion depth is limited to 30 for part 1 and 26 for part 2. Like the previous day, the problem space is too big to solve the task naively. At first, I reduced the problem space by ignoring valves with a rate of 0 and prevented moving back and forth between two rooms without doing anything. After this was still too slow, I cached the current maximum score for each recursion depth and abandoned paths early which fall below the current maximum with a certain threshold. This reduced the runtime significantly. Part 2 added an additional actor to the problem. Finding a way to implement this into my current solution took some thought, but after this was done, it worked right away. This was the first day where I managed to get into the top 1000, of which I was very happy about considering I started late on that day.

This was an interesting task as there were many different ways to reduce the problem space but you only had to discover some of them to make it computable.

### [Day 17]

Part 1 was basically implementing a simplified version of Tetris. Part 2 required a simulation of a trillion blocks which, again, was infeasible to do naively. The trick was to find a cycle which gives you the ability to jump forward in multiples of the cycle length. Fortunately, the provided inputs made finding a cycle easy because they all contain cycles that begin with a solid and flat top row. Unfortunately, in an early optimization attempt, I made the mistake of thinking I only have to save the position of the highest block in each column, completely disregarding the fact that new blocks can go below already placed ones in certain circumstances. It took me quite a while to notice my mistake.

### [Day 18]

Comparatively easy, considering the previous three days. I used recursive flood fill for part 2.

### [Day 19]

Very similar to day 16. It was an optimization problem with limited recursion depth if you perform a DFS. I used exactly the same approach as on day 16, i.e. caching the current maximum score at each step and abandoning paths early that perform worse with respect to a certain threshold. The additional challenge was that the score only starts to increase deep into the recursion (after the first of the most expensive robot has been built), so I had to find a way to measure the performance also when the recursion depth is low. I achived that by making the amount of built robots of the currently most expensive kind a preliminary score.

### [Day 20]

I implemented a LinkedList to form a ring. In hindsight, performance may be better if I had chosen an array, because moving array slices is very likely faster than traversing through a LinkedList, even though both are in `O(n)`. However, my choice of data structure made it easy to remember the original order of the elements (as the order in which they are moved is their original order), because I could just create a List of pointers to all elements of the LinkedList, since they keep their position in memory even after they are moved in the LinkedList. Part 2 only required slight additions to my solution for part 1.

### [Day 21]

The monkeys reappear. I solved part 1 by recursively evaluating the monkeys. Part 2 was a bit trickier. At first, I implemented a logarithmic search which worked quite well. But after looking at a small example on paper, I realized that it can be solved a lot faster by reversing the operations of one branch of the recursion. I pushed both solutions.

### [Day 22]

This was the most annoying problem this year. While it wasn't particularly hard, I spend a lot of time to find a general solution for arbitrary cube nets because I didn't want to just hardcode the mappings. In the end I found a general solution only for some situations and hardcoded the others to work on both my input and the example which resulted in much more conditions than what would be needed had I just hardcoded all the mappings to begin with. I have zero motivation to clean up this gigantic mess of an if-else chain that I ended up with.

### [Day 23]

Pretty straightforward simulation. I found good use for some Zig features on this day: I used a `u2` as a flag for the four directions and Zig's operator for wrapping addition to just do `direction +% 1` to cycle through them.

### [Day 24]

An optimization problem again, but this time I chose a BFS instead of a DFS as the "width" of the BFS is very limited due to the relatively low number of valid positions available at each iteration. Additionally, I computed the LCM of the width and height of the map to get the cycle length of the blizzard movement and discard positions that have been encountered already earlier during the same cycle position (i.e. `current_step % cycle_length`). This resulted in only a very small speed improvement because the solution to my input is only slightly higher than the cycle length.

### [Day 25]

This was a cool task. Even though the input only features positive numbers, I made sure my solution also works for negative ones. An interesting property of this numeral system is that negative numbers just have all the digits flipped to their complement.


[Day 01]: https://adventofcode.com/2022/day/1
[Day 02]: https://adventofcode.com/2022/day/2
[Day 03]: https://adventofcode.com/2022/day/3
[Day 04]: https://adventofcode.com/2022/day/4
[Day 05]: https://adventofcode.com/2022/day/5
[Day 06]: https://adventofcode.com/2022/day/6
[Day 07]: https://adventofcode.com/2022/day/7
[Day 08]: https://adventofcode.com/2022/day/8
[Day 09]: https://adventofcode.com/2022/day/9
[Day 10]: https://adventofcode.com/2022/day/10
[Day 11]: https://adventofcode.com/2022/day/11
[Day 12]: https://adventofcode.com/2022/day/12
[Day 13]: https://adventofcode.com/2022/day/13
[Day 14]: https://adventofcode.com/2022/day/14
[Day 15]: https://adventofcode.com/2022/day/15
[Day 16]: https://adventofcode.com/2022/day/16
[Day 17]: https://adventofcode.com/2022/day/17
[Day 18]: https://adventofcode.com/2022/day/18
[Day 19]: https://adventofcode.com/2022/day/19
[Day 20]: https://adventofcode.com/2022/day/20
[Day 21]: https://adventofcode.com/2022/day/21
[Day 22]: https://adventofcode.com/2022/day/22
[Day 23]: https://adventofcode.com/2022/day/23
[Day 24]: https://adventofcode.com/2022/day/24
[Day 25]: https://adventofcode.com/2022/day/25
