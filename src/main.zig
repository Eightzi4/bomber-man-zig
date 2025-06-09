const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");
const Menu = @import("Menu.zig");
const Game = @import("Game.zig");
const Player = @import("Player.zig");
const Data = @import("Data.zig");

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(1000, 650, "Playing with Fire Reborn");
    rl.setTargetFPS(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));
    rl.setExitKey(.delete);
    defer rl.closeWindow();

    var data = Data.init();
    defer data.deinit();

    data.run();
}
