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
    rl.initWindow(cons.WINDOW_SIZE.x, cons.WINDOW_SIZE.y, "Playing with Fire Reborn");
    rl.setTargetFPS(rl.getMonitorRefreshRate(rl.getCurrentMonitor()));
    rl.setExitKey(.delete);
    defer rl.closeWindow();

    var data = Data.init();
    defer data.deinit();

    while (!rl.windowShouldClose()) {
        switch (data.state) {
            .initialization => data.state = .menu,
            .menu => data.state = runMenu(),
            .game => data.state = runGame(&data),
            .quit => break,
        }
    }
}

fn runMenu() Data.State {
    var menu = Menu.init();
    defer menu.deinit();

    while (!rl.windowShouldClose()) {
        if (menu.exit_game) return .quit;
        if (menu.play_game) return .game;

        menu.update();
        menu.draw();
    }

    return .quit;
}

fn runGame(data: *Data) Data.State {
    var game = Game.init(data);

    game.opt_players.set(.alpha, .init(
        .{ .x = cons.CELL_SIZE * 5 + cons.CELL_SIZE / 2, .y = cons.CELL_SIZE + cons.CELL_SIZE / 2 },
        game.world_id,
        .init(std.enums.EnumFieldStruct(Player.ActionVariant, rl.KeyboardKey, null){
            .left = .a,
            .right = .d,
            .up = .w,
            .down = .s,
            .place_dynamite = .space,
        }),
        &game.team_textures.get(.alpha),
    ));

    game.opt_players.set(.beta, .init(
        .{ .x = cons.CELL_SIZE * 17 + cons.CELL_SIZE / 2, .y = cons.CELL_SIZE * 11 + cons.CELL_SIZE / 2 },
        game.world_id,
        .init(std.enums.EnumFieldStruct(Player.ActionVariant, rl.KeyboardKey, null){
            .left = .left,
            .right = .right,
            .up = .up,
            .down = .down,
            .place_dynamite = .enter,
        }),
        &game.team_textures.get(.beta),
    ));

    while (!rl.windowShouldClose()) {
        if (rl.isKeyDown(.escape)) return .menu;

        game.update();
        game.draw();
    }

    return .quit;
}
