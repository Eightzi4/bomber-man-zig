const types = @import("types.zig");

pub const CELL_SIZE = 50;
pub const GUI_SIZE = CELL_SIZE * 4;
pub const GRID_SIZE = types.Vec2{ .x = 15, .y = 13 };
pub const WINDOW_SIZE = types.Vec2{ .x = GRID_SIZE.x * CELL_SIZE + GUI_SIZE, .y = GRID_SIZE.y * CELL_SIZE };
//TODO: Refactor
pub const TEXTURE_ASSET_NAMES = [_][]const u8{
    "ground.jpg",
    "wall.png",
    "barrel.png",

    "blue_player.png",
    "red_player.png",

    "blue_dynamite.png",
    "red_dynamite.png",

    "blue_horizontal_explosion.png",
    "blue_vertical_explosion.png",
    "blue_crossed_explosion.png",
    "red_horizontal_explosion.png",
    "red_vertical_explosion.png",
    "red_crossed_explosion.png",
};
pub const EXPLOSION_DURATION = 100;
