# Advent of Code 2022

My solutions written in Zig.

## Example compilation
```
zig build-exe 01.zig -O ReleaseFast -lc
```
`-lc` will link against `libc`. I'm using the C allocator because of speed™.

## Running tests
```
zig test 01.zig
```
