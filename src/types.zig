const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const cons = @import("constants.zig");
const funcs = @import("functions.zig");

pub const Vec2 = struct {
    x: i32,
    y: i32,

    pub fn eql(self: @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn add(self: @This(), other: @This()) @This() {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn mul_scalar(self: @This(), scalar: i32) @This() {
        return .{
            .x = self.x * scalar,
            .y = self.y * scalar,
        };
    }
};

pub const Texture = enum(u8) {
    ground,
    wall,
    death_wall,
    barrel,
    dynamite_1,
    dynamite_2,
    explosion_1,
    explosion_2,
    hearth,
    player_down_1,
    player_down_2,
    player_down_3,
    player_side_1,
    player_side_2,
    player_side_3,
    player_up_1,
    player_up_2,
};

pub const TeamTextures = struct {
    player_textures: PlayerTextures,
    dynamite_textures: [2]rl.Texture2D,
    explosion_textures: [2]rl.Texture2D,
};

pub const PlayerTextures = struct {
    side: [3]rl.Texture2D,
    down: [2]rl.Texture2D,
    up: [2]rl.Texture2D,
};

pub const Team = enum {
    alpha,
    beta,
    gamma,
    delta,
};

pub const ExplosionVariant = enum {
    horizontal,
    vertical,
    crossed,
};

pub const DynamiteState = enum {
    idle,
    exploding,
    exploded,
};

pub const Wall = struct {
    body_id: b2.b2BodyId,
};

pub const Barrel = struct {
    body_id: b2.b2BodyId,
};

pub const Explosion = struct {
    team: Team,
    variant: ExplosionVariant,
    timer: f32,

    pub fn update(self: *@This()) void {
        self.timer -= cons.PHYSICS_TIMESTEP;
    }
};

pub const Cell = struct {
    tag: Texture,
    variant: CellVariant,

    pub fn initGround() @This() {
        return .{
            .tag = .ground,
            .variant = .{ .ground = {} },
        };
    }

    pub fn initWall(x: u8, y: u8, world_id: b2.b2WorldId) @This() {
        return .{
            .tag = .wall,
            .variant = .{ .wall = .{ .body_id = funcs.createCollider(x, y, world_id) } },
        };
    }

    pub fn initBarrel(x: u8, y: u8, world_id: b2.b2WorldId) @This() {
        return .{
            .tag = .barrel,
            .variant = .{ .barrel = .{ .body_id = funcs.createCollider(x, y, world_id) } },
        };
    }

    pub fn initExplosion(team: Team, variant: ExplosionVariant) @This() {
        return .{
            .tag = if (variant == .crossed) .explosion_2 else .explosion_1,
            .variant = .{ .explosion_1 = .{
                .team = team,
                .variant = variant,
                .timer = cons.EXPLOSION_DURATION,
            } },
        };
    }

    pub fn initDynamite(team: Team) @This() {
        return .{
            .tag = .dynamite_1,
            .variant = .{ .dynamite_1 = .init(team) },
        };
    }
};

pub const CellVariant = union {
    ground: void,
    wall: Wall,
    death_wall: Wall,
    barrel: Barrel,
    dynamite_1: Dynamite,
    dynamite_2: Dynamite,
    explosion_1: Explosion,
    explosion_2: Explosion,
    hearth: void,
    player_down_1: void,
    player_down_2: void,
    player_down_3: void,
    player_side_1: void,
    player_side_2: void,
    player_side_3: void,
    player_up_1: void,
    player_up_2: void,
};

pub const Dynamite = struct {
    team: Team,
    state: DynamiteState,
    timer: f32,
    radius: u8,

    pub fn init(team: Team) @This() {
        return .{
            .team = team,
            .state = .idle,
            .timer = 3,
            .radius = 4,
        };
    }

    pub fn update(self: *@This()) void {
        self.timer -= cons.PHYSICS_TIMESTEP;
    }

    pub fn draw(self: @This(), textures: [2]rl.Texture2D) void {
        if (self.state == .idle) {
            funcs.drawTexture(textures[0], self.position);
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
