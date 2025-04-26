const std = @import("std");
const rl = @import("raylib");

const types = @import("types.zig");
const cons = @import("constants.zig");
const Game = @import("Game.zig");
const Player = @import("Player.zig");

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();
    const random = D: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
        var prng = std.Random.DefaultPrng.init(seed);
        break :D prng.random();
    };

    rl.initWindow(cons.WINDOW_SIZE.x, cons.WINDOW_SIZE.y, "Playing with Fire");
    defer rl.closeWindow();

    rl.setTargetFPS(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));

    var game = Game.init(debug_allocator.allocator(), random);
    defer game.deinit();

    game.optional_players[0] = Player.init(
        .{ .x = cons.CELL_SIZE * 5 + cons.CELL_SIZE / 2, .y = cons.CELL_SIZE + cons.CELL_SIZE / 2 },
        game.world_id,
        .blue,
        .{
            .left = .a,
            .right = .d,
            .up = .w,
            .down = .s,
            .throw_dynamite = .space,
        },
    );

    game.optional_players[1] = Player.init(
        .{ .x = cons.CELL_SIZE * 17 + cons.CELL_SIZE / 2, .y = cons.CELL_SIZE * 11 + cons.CELL_SIZE / 2 },
        game.world_id,
        .red,
        .{
            .left = .left,
            .right = .right,
            .up = .up,
            .down = .down,
            .throw_dynamite = .enter,
        },
    );

    std.debug.print("{} vs {}", .{ @sizeOf(types.Texture2), @sizeOf(types.Texture) });

    while (!rl.windowShouldClose()) {
        game.update();
        game.draw();
    }
}
