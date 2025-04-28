const std = @import("std");

const types = @import("types.zig");

pub const CELL_SIZE = 50;
pub const GUI_SIZE = CELL_SIZE * 4;
pub const GRID_SIZE = types.Vec2{ .x = 15, .y = 13 };
pub const WINDOW_SIZE = types.Vec2{ .x = GRID_SIZE.x * CELL_SIZE + GUI_SIZE, .y = GRID_SIZE.y * CELL_SIZE };
pub const EXPLOSION_DURATION = 100;
