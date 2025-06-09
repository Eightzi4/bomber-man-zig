const std = @import("std");

const types = @import("types.zig");

pub const ASSET_DIRECTORY_PATH = "assets/images";

pub const DIRECTIONS = [4]types.Vec2(i32){
    .{ .x = -1, .y = 0 },
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = -1 },
    .{ .x = 0, .y = 1 },
};

//pub const CELL_SIZE = 50; // pixels
pub const GUI_SIZE = 5;
pub const GRID_SIZE = types.Vec2(comptime_int){ .x = 15, .y = 13 };

pub const PHYSICS_UNIT = 50; // magic value
pub const PHYSICS_TIMESTEP = 1.0 / 60.0; // 60 Hz
pub const PHYSICS_SUBSTEP_COUNT = 4;

pub const EXPLOSION_DURATION = 1; // seconds
pub const INVINCIBILITY_DURATION = 3; // seconds
pub const FLASH_COOLDOWN = 5; // seconds

pub const MAX_HEALTH = 3;
pub const MAX_DYNAMITE_COUNT = 10;
