const std = @import("std");
const rl = @import("raylib");
const b2 = glbs.b2;

const glbs = @import("globals.zig");
const funcs = @import("functions.zig");
const Player = @import("Player.zig");

pub fn Vec2(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

pub const Texture = @import("resources").Texture;

pub const TeamTextures = struct {
    player_textures: PlayerTextures,
    dynamite_textures: [2]rl.Texture2D,
    explosion_textures: [2]rl.Texture2D,
};

pub const PlayerTextures = struct {
    side: [3]rl.Texture2D,
    down: [3]rl.Texture2D,
    up: [3]rl.Texture2D,
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

pub const UpgradeUnderneath = enum {
    dynamite,
    heal,
    radius,
    speed,
    teleport,
    none,
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
    upgrade_underneath: UpgradeUnderneath,

    pub fn update(self: *@This()) void {
        self.timer -= glbs.PHYSICS_TIMESTEP;
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

    pub fn initWall(world_id: b2.b2WorldId, coords: Vec2(u8)) @This() {
        return .{
            .tag = .wall,
            .variant = .{ .wall = .{ .body_id = funcs.createCollider(world_id, coords) } },
        };
    }

    pub fn initBarrel(world_id: b2.b2WorldId, coords: Vec2(u8)) @This() {
        return .{
            .tag = .barrel,
            .variant = .{ .barrel = .{ .body_id = funcs.createCollider(world_id, coords) } },
        };
    }

    pub fn initExplosion(team: Team, variant: ExplosionVariant, upgrade_underneath: UpgradeUnderneath) @This() {
        return .{
            .tag = if (variant == .crossed) .explosion_2 else .explosion_1,
            .variant = .{ .explosion_1 = .{
                .team = team,
                .variant = variant,
                .timer = glbs.EXPLOSION_DURATION,
                .upgrade_underneath = upgrade_underneath,
            } },
        };
    }

    pub fn initDynamite(team: Team, radius: u8) @This() {
        return .{
            .tag = .dynamite_1,
            .variant = .{ .dynamite_1 = .init(team, radius) },
        };
    }

    pub fn initUpgrade(upgrade_variant: UpgradeUnderneath) @This() {
        return .{
            .tag = @enumFromInt(@intFromEnum(Texture.upgrade_dynamite) + @intFromEnum(upgrade_variant)),
            .variant = .{ .upgrade_dynamite = {} },
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
    upgrade_dynamite: void,
    upgrade_heal: void,
    upgrade_radius: void,
    upgrade_speed: void,
    upgrade_teleport: void,
    hearth: void,
    invincible_hearth: void,
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

    pub fn init(team: Team, radius: u8) @This() {
        return .{
            .team = team,
            .state = .idle,
            .timer = glbs.EXPLOSION_DELAY,
            .radius = radius,
        };
    }

    pub fn update(self: *@This()) void {
        self.timer -= glbs.PHYSICS_TIMESTEP;
    }
};

pub const PlayerConfig = struct {
    team_color: rl.Color,
    key_bindings: std.enums.EnumArray(Player.MoveDirection, rl.KeyboardKey),
};

pub const GameSettings = struct {
    player_count: i32 = 2,
    player_configs: [4]PlayerConfig,
};
