const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");
const Game = @import("Game.zig");

pub const Dynamite = struct {
    position: b2.b2Vec2,
    radius: u8,
    team_color: types.TeamColor,
    timer: i16,

    pub fn init(position: b2.b2Vec2, team_color: types.TeamColor) @This() {
        return .{
            .position = .{
                .x = @divTrunc(position.x, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
                .y = @divTrunc(position.y, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
            },
            .radius = 4,
            .team_color = team_color,
            .timer = 500,
        };
    }

    pub fn update(self: *@This()) void {
        self.timer -= 1;
    }

    pub fn draw(self: @This(), textures: std.HashMap(types.TextureWrapper, rl.Texture2D, types.TextureContext, std.hash_map.default_max_load_percentage)) void {
        if (self.timer > 0) {
            rl.drawTexture(
                textures.get(.dynamite(self.team_color)) orelse @panic("HashMap doesn't contain this key!"),
                @intFromFloat(self.position.x - cons.CELL_SIZE / 2),
                @intFromFloat(self.position.y - cons.CELL_SIZE / 2),
                rl.Color.white,
            );
        }
    }
};

const KeyBindings = struct {
    left: rl.KeyboardKey,
    right: rl.KeyboardKey,
    up: rl.KeyboardKey,
    down: rl.KeyboardKey,
    throw_dynamite: rl.KeyboardKey,
};

speed: f32,
body_id: b2.b2BodyId,
team_color: types.TeamColor,
optional_dynamites: [10]?Dynamite = [_]?Dynamite{null} ** 10,
key_bindings: KeyBindings,

pub fn init(position: b2.b2Vec2, world_id: b2.b2WorldId, team_color: types.TeamColor, key_bindings: KeyBindings) @This() {
    return .{
        .speed = cons.CELL_SIZE * 4,
        .team_color = team_color,
        .key_bindings = key_bindings,
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
    };
}

pub fn update(self: *@This()) void {
    self.updateDynamites();

    const input_vector = b2.b2Vec2{
        .x = if (rl.isKeyDown(self.key_bindings.right)) 1.0 else if (rl.isKeyDown(self.key_bindings.left)) -1.0 else 0.0,
        .y = if (rl.isKeyDown(self.key_bindings.down)) 1.0 else if (rl.isKeyDown(self.key_bindings.up)) -1.0 else 0.0,
    };

    b2.b2Body_SetLinearVelocity(self.body_id, b2.b2MulSV(self.speed, input_vector));

    if (rl.isKeyPressed(self.key_bindings.throw_dynamite)) self.throwDynamite();
}

pub fn draw(self: *@This(), textures: std.HashMap(types.TextureWrapper, rl.Texture2D, types.TextureContext, std.hash_map.default_max_load_percentage)) void {
    self.drawDynamites(textures);

    const position = b2.b2Body_GetPosition(self.body_id);

    rl.drawTexture(
        textures.get(.player(self.team_color)) orelse @panic("HashMap doesn't contain this key!"),
        @intFromFloat(position.x - cons.CELL_SIZE / 2),
        @intFromFloat(position.y - cons.CELL_SIZE / 2),
        rl.Color.white,
    );
}

fn throwDynamite(self: *@This()) void {
    for (&self.optional_dynamites) |*dynamite_slot| {
        if (dynamite_slot.* == null) {
            dynamite_slot.* = Dynamite.init(b2.b2Body_GetPosition(self.body_id), self.team_color);

            return;
        }
    }
}

pub fn updateDynamites(self: *@This()) void {
    for (&self.optional_dynamites) |*optinal_dynamite| if (optinal_dynamite.*) |*dynamite| {
        dynamite.update();
    };
}

fn drawDynamites(self: *@This(), textures: std.HashMap(types.TextureWrapper, rl.Texture2D, types.TextureContext, std.hash_map.default_max_load_percentage)) void {
    for (&self.optional_dynamites) |*optinal_dynamite| if (optinal_dynamite.*) |*dynamite| {
        dynamite.draw(textures);
    };
}
