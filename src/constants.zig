const std = @import("std");

const types = @import("types.zig");

pub const DIRECTIONS = [4]types.Vec2{
    .{ .x = -1, .y = 0 },
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = -1 },
    .{ .x = 0, .y = 1 },
};

pub const ASSET_DIRECTORY_PATH = "assets/images";

pub const CELL_SIZE = 50; //pixels
pub const GUI_SIZE = CELL_SIZE * 4;
pub const GRID_SIZE = types.Vec2{ .x = 15, .y = 13 };
pub const WINDOW_SIZE = types.Vec2{ .x = GRID_SIZE.x * CELL_SIZE + GUI_SIZE, .y = GRID_SIZE.y * CELL_SIZE };

pub const EXPLOSION_DURATION = 1; // seconds

pub const PHYSICS_TIMESTEP = 1.0 / 60.0; // 60 Hz
pub const PHYSICS_SUBSTEP_COUNT = 4;
