const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const Data = @import("Data.zig");

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(1000, 650, "Playing with Fire Reborn");
    defer rl.closeWindow();
    rl.setTargetFPS(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));
    rl.setExitKey(.delete);

    var data = Data.init();
    defer data.deinit();

    data.run();
}
