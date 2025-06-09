const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");
const funcs = @import("functions.zig");
const Game = @import("Game.zig");

pub const MoveDirection = enum {
    left,
    right,
    up,
    down,
};

pub const MoveAction = struct {
    binded_key: rl.KeyboardKey,
    cached_input: bool = false,
    last_pressed: f32 = -1.0,
};

pub const Actions = struct {
    movement: std.enums.EnumArray(
        MoveDirection,
        MoveAction,
    ),
    place_dynamite: struct {
        binded_key: rl.KeyboardKey,
        cached_input: bool = false,
    },
};

dynamite_count: u8,
explosion_radius: u8,
health: u8,
invincibility_timer: f32,
flash_timer: f32,
speed: f32,
old_position: b2.b2Vec2,
body_id: b2.b2BodyId,
textures: *const types.PlayerTextures,
actions: Actions,

pub fn init(position: b2.b2Vec2, world_id: b2.b2WorldId, actions: Actions, textures: *const types.PlayerTextures) @This() {
    const pos = b2.b2Vec2{ .x = cons.PHYSICS_UNIT * position.x, .y = cons.PHYSICS_UNIT * position.y };

    return .{
        .explosion_radius = 2,
        .dynamite_count = 1,
        .health = 3,
        .invincibility_timer = 0,
        .flash_timer = std.math.floatMax(f32),
        .speed = cons.PHYSICS_UNIT * 5,
        .old_position = pos,
        .body_id = D: {
            var body_def = b2.b2DefaultBodyDef();
            body_def.position = pos;
            body_def.type = b2.b2_dynamicBody;
            body_def.fixedRotation = true;
            body_def.linearDamping = 10;

            const body_id = b2.b2CreateBody(world_id, &body_def);

            _ = b2.b2CreateCircleShape(body_id, &b2.b2DefaultShapeDef(), &b2.b2Circle{ .radius = @as(f32, @floatFromInt(cons.PHYSICS_UNIT)) / 2 });

            break :D body_id;
        },
        .actions = actions,
        .textures = textures,
    };
}

pub fn update(self: *@This()) void {
    for (&self.actions.movement.values) |*action| action.cached_input = rl.isKeyDown(action.binded_key);

    if (!self.actions.place_dynamite.cached_input) self.actions.place_dynamite.cached_input = rl.isKeyPressed(self.actions.place_dynamite.binded_key);

    self.old_position = b2.b2Body_GetPosition(self.body_id);
}

pub fn fixedUpdate(self: *@This()) void {
    self.invincibility_timer -= cons.PHYSICS_TIMESTEP;
    self.flash_timer -= cons.PHYSICS_TIMESTEP;

    handleMovement(self.body_id, self.speed, self.actions.movement);
}

pub fn draw(self: *@This(), alpha: f32, cell_size: f32) void {
    const position = b2.b2Body_GetPosition(self.body_id);
    const draw_position = funcs.physPosToScreenPos(.{
        .x = (self.old_position.x * (1 - alpha) + position.x * alpha),
        .y = (self.old_position.y * (1 - alpha) + position.y * alpha),
    }, cell_size);

    funcs.drawCenteredTexture(self.textures.down[0], draw_position, 0, cell_size);
}

pub fn hurt(self: *@This()) void {
    if (self.invincibility_timer <= 0 and self.health > 0) {
        self.health -= 1;
        if (self.health == 0) b2.b2DestroyBody(self.body_id) else self.invincibility_timer = cons.INVINCIBILITY_DURATION;
    }
}

pub fn heal(self: *@This()) void {
    self.health += 1;
}

fn handleMovement(body_id: b2.b2BodyId, speed: f32, movement_actions: std.enums.EnumArray(MoveDirection, MoveAction)) void {
    var input_vector = b2.b2Vec2{
        .x = @floatFromInt(@as(i2, @intFromBool(movement_actions.get(.right).cached_input)) - @as(i2, @intFromBool(movement_actions.get(.left).cached_input))),
        .y = @floatFromInt(@as(i2, @intFromBool(movement_actions.get(.down).cached_input)) - @as(i2, @intFromBool(movement_actions.get(.up).cached_input))),
    };

    const position = b2.b2Body_GetPosition(body_id);

    if (input_vector.x == 0 and input_vector.y != 0) {
        const grid_position_x = @divFloor(@as(i32, @intFromFloat(position.x)), cons.PHYSICS_UNIT);
        const offset = position.x - cons.PHYSICS_UNIT * @as(f32, @floatFromInt(grid_position_x));

        if (@mod(grid_position_x, 2) == 0)
            input_vector.x = if (offset < 0) -1 else 1
        else
            input_vector.x = if (offset < -cons.PHYSICS_UNIT / 5) 1 else if (offset > cons.PHYSICS_UNIT / 5) -1 else 0;
    } else if (input_vector.y == 0 and input_vector.x != 0) {
        const grid_position_y = @divFloor(@as(i32, @intFromFloat(position.y)), cons.PHYSICS_UNIT);
        const offset = position.y - cons.PHYSICS_UNIT * @as(f32, @floatFromInt(grid_position_y));

        if (@mod(grid_position_y, 2) == 0)
            input_vector.y = if (offset < 0) -1 else 1
        else
            input_vector.y = if (offset < -cons.PHYSICS_UNIT / 5) 1 else if (offset > cons.PHYSICS_UNIT / 5) -1 else 0;
    }

    b2.b2Body_SetLinearVelocity(body_id, b2.b2MulSV(speed, input_vector));
}
