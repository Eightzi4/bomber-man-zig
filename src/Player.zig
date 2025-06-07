const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");
const funcs = @import("functions.zig");
const Game = @import("Game.zig");

pub const Action = struct {
    binded_key: rl.KeyboardKey,
    cached_input: bool = false,
};

pub const ActionVariant = enum {
    left,
    right,
    up,
    down,
    place_dynamite,
};

health: u8,
invincibility_timer: f32,
speed: f32,
old_position: b2.b2Vec2,
body_id: b2.b2BodyId,
actions: std.enums.EnumArray(ActionVariant, Action),
textures: *const types.TeamTextures,

pub fn init(position: b2.b2Vec2, world_id: b2.b2WorldId, key_bindings: std.enums.EnumArray(ActionVariant, rl.KeyboardKey), textures: *const types.TeamTextures) @This() {
    return .{
        .health = 3,
        .invincibility_timer = 0,
        .speed = cons.CELL_SIZE * 5,
        .old_position = position,
        .body_id = D: {
            var body_def = b2.b2DefaultBodyDef();
            body_def.position = position;
            body_def.type = b2.b2_dynamicBody;
            body_def.fixedRotation = true;
            body_def.linearDamping = 7.0;

            const body_id = b2.b2CreateBody(world_id, &body_def);

            _ = b2.b2CreateCircleShape(body_id, &b2.b2DefaultShapeDef(), &b2.b2Circle{ .radius = cons.CELL_SIZE / 2 });

            break :D body_id;
        },
        .actions = .init(std.enums.EnumFieldStruct(ActionVariant, Action, null){
            .left = .{ .binded_key = key_bindings.get(.left) },
            .right = .{ .binded_key = key_bindings.get(.right) },
            .up = .{ .binded_key = key_bindings.get(.up) },
            .down = .{ .binded_key = key_bindings.get(.down) },
            .place_dynamite = .{ .binded_key = key_bindings.get(.place_dynamite) },
        }),
        .textures = textures,
    };
}

pub fn update(self: *@This()) void {
    // Keys that are held down
    for (self.actions.values[0..4]) |*action| action.cached_input = rl.isKeyDown(action.binded_key);
    for (self.actions.values[4..]) |*action| if (!action.cached_input) {
        action.cached_input = rl.isKeyPressed(action.binded_key);
    };

    self.old_position = b2.b2Body_GetPosition(self.body_id);
}

pub fn fixedUpdate(self: *@This()) void {
    self.invincibility_timer -= cons.PHYSICS_TIMESTEP;

    handleMovement(self.body_id, self.speed, self.actions);
}

pub fn draw(self: *@This(), alpha: f32) void {
    const position = b2.b2Body_GetPosition(self.body_id);
    const draw_position = b2.b2Vec2{
        .x = self.old_position.x * (1 - alpha) + position.x * alpha,
        .y = self.old_position.y * (1 - alpha) + position.y * alpha,
    };

    funcs.drawCenteredTexture(self.textures.player_textures.down[0], draw_position, 0);
}

// TODO: Remove '> 0' check
pub fn hurt(self: *@This()) void {
    if (self.invincibility_timer <= 0 and self.health > 0) {
        self.health -= 1;
        self.invincibility_timer = cons.INVINCIBILITY_DURATION;
    }
}

fn handleMovement(body_id: b2.b2BodyId, speed: f32, actions: std.enums.EnumArray(ActionVariant, Action)) void {
    var input_vector = b2.b2Vec2{
        .x = @floatFromInt(@as(i2, @intFromBool(actions.get(.right).cached_input)) - @as(i2, @intFromBool(actions.get(.left).cached_input))),
        .y = @floatFromInt(@as(i2, @intFromBool(actions.get(.down).cached_input)) - @as(i2, @intFromBool(actions.get(.up).cached_input))),
    };

    const position = b2.b2Body_GetPosition(body_id);

    // Sliding around corners (only works if walls are placed on even grid coordinates)
    if (input_vector.x == 0 and input_vector.y != 0) {
        const grid_position_x = @divFloor(@as(i32, @intFromFloat(position.x - cons.GUI_SIZE)), cons.CELL_SIZE);
        const offset = position.x - cons.GUI_SIZE - cons.CELL_SIZE * @as(f32, @floatFromInt(grid_position_x)) - cons.CELL_SIZE / 2;

        if (@mod(grid_position_x, 2) == 0)
            input_vector.x = if (offset < 0) -1 else 1
        else
            input_vector.x = if (offset < -cons.CELL_SIZE / 5) 1 else if (offset > cons.CELL_SIZE / 5) -1 else 0;
    } else if (input_vector.y == 0 and input_vector.x != 0) {
        const grid_position_y = @divFloor(@as(i32, @intFromFloat(position.y)), cons.CELL_SIZE);
        const offset = position.y - cons.CELL_SIZE * @as(f32, @floatFromInt(grid_position_y)) - cons.CELL_SIZE / 2;

        if (@mod(grid_position_y, 2) == 0)
            input_vector.y = if (offset < 0) -1 else 1
        else
            input_vector.y = if (offset < -cons.CELL_SIZE / 5) 1 else if (offset > cons.CELL_SIZE / 5) -1 else 0;
    }

    b2.b2Body_SetLinearVelocity(body_id, b2.b2MulSV(speed, input_vector));
}
