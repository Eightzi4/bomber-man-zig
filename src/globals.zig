const types = @import("types.zig");

pub const b2 = @cImport(@cInclude("box2d/box2d.h"));

pub const DIRECTIONS = [4]types.Vec2(i32){
    .{ .x = -1, .y = 0 },
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = -1 },
    .{ .x = 0, .y = 1 },
};

pub const PLAYER_START_POSITIONS = [4]b2.b2Vec2{
    .{ .x = 1, .y = 1 },
    .{ .x = 13, .y = 11 },
    .{ .x = 1, .y = 11 },
    .{ .x = 13, .y = 1 },
};

pub const GUI_SIZE = 5; // cells
pub const GRID_SIZE = types.Vec2(comptime_int){ .x = 15, .y = 13 };

pub const PHYSICS_UNIT = 50; // magic value to make physics work
pub const PHYSICS_TIMESTEP = 1.0 / 60.0; // 60 Hz
pub const PHYSICS_SUBSTEP_COUNT = 4;

pub const EXPLOSION_DELAY = 3; // seconds
pub const EXPLOSION_DURATION = 1; // seconds
pub const INVINCIBILITY_DURATION = 3; // seconds
pub const INITIAL_TELEPORT_COOLDOWN = 5.5; // seconds

pub const ANIMATION_PLAYBACK_SPEED = 5;
pub const PLAYER_ANIMATION_SEQUENCE = [_]u8{ 1, 0, 2, 0 };

pub const START_HEALTH = 3;
pub const MAX_DYNAMITE_COUNT = 10;
