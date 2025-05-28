const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");
const Game = @import("Game.zig");

const Action = struct {
    binded_key: rl.KeyboardKey,
    cached_input: bool = false,
};

const PlayerActions = struct {
    left: Action,
    right: Action,
    up: Action,
    down: Action,
    throw_dynamite: Action,
};

const Dynamite = struct {
    position: b2.b2Vec2,
    radius: u8,
    team_color: types.TeamColor,
    state: enum(u8) {
        idle,
        exploding,
        exploded,
    },
    timer: f32,

    pub fn init(aligned_position: b2.b2Vec2, team_color: types.TeamColor) @This() {
        return .{
            .position = aligned_position,
            .radius = 4,
            .team_color = team_color,
            .state = .idle,
            .timer = 3,
        };
    }

    pub fn update(self: *@This()) void {
        self.timer -= cons.PHYSICS_TIMESTEP;
    }

    pub fn draw(self: @This(), textures: types.TextureHashMap) void {
        if (self.state == .idle) {
            rl.drawTexture(
                textures.get(.dynamite(self.team_color)) orelse @panic("HashMap doesn't contain this key!"),
                @intFromFloat(self.position.x - cons.CELL_SIZE / 2),
                @intFromFloat(self.position.y - cons.CELL_SIZE / 2),
                rl.Color.white,
            );
        }
    }

    pub fn switchState(self: *@This()) void {
        switch (self.state) {
            .idle => {
                self.state = .exploding;
                self.timer = cons.EXPLOSION_DURATION;
            },
            .exploding => {
                self.state = .exploded;
            },
            .exploded => unreachable,
        }
    }
};

health: u8,
invincibility_timer: f32,
speed: f32,
old_position: b2.b2Vec2,
team_color: types.TeamColor,
body_id: b2.b2BodyId,
optional_dynamites: [cons.MAX_DYNAMITE_COUNT]?Dynamite,
actions: PlayerActions,

pub fn init(position: b2.b2Vec2, world_id: b2.b2WorldId, team_color: types.TeamColor, key_bindings: [@typeInfo(PlayerActions).@"struct".fields.len]rl.KeyboardKey) @This() {
    return .{
        .health = 3,
        .invincibility_timer = 0,
        .speed = cons.CELL_SIZE * 5,
        .old_position = position,
        .team_color = team_color,
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
        .optional_dynamites = .{null} ** cons.MAX_DYNAMITE_COUNT,
        .actions = .{
            .left = .{ .binded_key = key_bindings[0] },
            .right = .{ .binded_key = key_bindings[1] },
            .up = .{ .binded_key = key_bindings[2] },
            .down = .{ .binded_key = key_bindings[3] },
            .throw_dynamite = .{ .binded_key = key_bindings[4] },
        },
    };
}

pub fn update(self: *@This()) void {
    // Keys that are held down
    inline for (@typeInfo(@TypeOf(self.actions)).@"struct".fields[0..4]) |field| {
        @field(self.actions, field.name).cached_input = rl.isKeyDown(@field(self.actions, field.name).binded_key);
    }

    // Keys that are pressed (+ sticky)
    inline for (@typeInfo(@TypeOf(self.actions)).@"struct".fields[4..]) |field| {
        if (!@field(self.actions, field.name).cached_input) {
            @field(self.actions, field.name).cached_input = rl.isKeyPressed(@field(self.actions, field.name).binded_key);
        }
    }

    self.old_position = b2.b2Body_GetPosition(self.body_id);
}

pub fn fixedUpdate(self: *@This()) void {
    self.updateDynamites();

    self.invincibility_timer -= cons.PHYSICS_TIMESTEP;

    handleMovement(self.body_id, self.speed, self.actions);

    if (self.actions.throw_dynamite.cached_input) self.throwDynamite();
}

pub fn draw(self: *@This(), textures: types.TextureHashMap, alpha: f32) void {
    self.drawDynamites(textures);

    const position = b2.b2Body_GetPosition(self.body_id);
    const draw_position = b2.b2Vec2{
        .x = self.old_position.x * (1 - alpha) + position.x * alpha,
        .y = self.old_position.y * (1 - alpha) + position.y * alpha,
    };

    rl.drawTexture(
        textures.get(.player(self.team_color)) orelse @panic("HashMap doesn't contain this key!"),
        @intFromFloat(draw_position.x - cons.CELL_SIZE / 2),
        @intFromFloat(draw_position.y - cons.CELL_SIZE / 2),
        rl.Color.white,
    );
}

// TODO: Remove '> 0' check
pub fn hurt(self: *@This()) void {
    if (self.invincibility_timer <= 0 and self.health > 0) {
        self.health -= 1;
        self.invincibility_timer = cons.INVINCIBILITY_DURATION;
    }
}

fn handleMovement(body_id: b2.b2BodyId, speed: f32, actions: PlayerActions) void {
    var input_vector = b2.b2Vec2{
        .x = @floatFromInt(@as(i2, @intFromBool(actions.right.cached_input)) - @as(i2, @intFromBool(actions.left.cached_input))),
        .y = @floatFromInt(@as(i2, @intFromBool(actions.down.cached_input)) - @as(i2, @intFromBool(actions.up.cached_input))),
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

fn throwDynamite(self: *@This()) void {
    self.actions.throw_dynamite.cached_input = false;

    const position = b2.b2Body_GetPosition(self.body_id);
    const aligned_position = b2.b2Vec2{
        .x = @divTrunc(position.x, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
        .y = @divTrunc(position.y, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
    };

    // This still allows multiple dynamites to be placed in single cell, but unlikely to happen
    for (&self.optional_dynamites) |*dynamite_slot| {
        if (dynamite_slot.*) |dynamite| {
            if (dynamite.position.x == aligned_position.x and dynamite.position.y == aligned_position.y) break;
        } else {
            dynamite_slot.* = Dynamite.init(aligned_position, self.team_color);

            return;
        }
    }
}

fn updateDynamites(self: *@This()) void {
    for (&self.optional_dynamites) |*optinal_dynamite| if (optinal_dynamite.*) |*dynamite| {
        dynamite.update();
    };
}

fn drawDynamites(self: *@This(), textures: types.TextureHashMap) void {
    for (&self.optional_dynamites) |*optinal_dynamite| if (optinal_dynamite.*) |*dynamite| {
        dynamite.draw(textures);
    };
}
