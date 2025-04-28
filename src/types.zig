const std = @import("std");

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

pub const TeamColor = enum(u2) {
    blue,
    red,
    yellow,
    green,
};

pub const ExplosionVariant = enum(u2) {
    horizontal,
    vertical,
    crossed,
    unused,
};

pub const Texture = packed union {
    ground: void,
    wall: void,
    barrel: void,
    player: packed struct { team_color: TeamColor },
    dynamite: packed struct { team_color: TeamColor },
    explosion: packed struct { team_color: TeamColor, variant: ExplosionVariant },
};

pub const TextureWrapper = packed struct {
    tag: std.meta.FieldEnum(Texture),
    data: Texture,

    pub fn init(tag: std.meta.FieldEnum(Texture), data: Texture) TextureWrapper {
        return .{
            .tag = tag,
            .data = data,
        };
    }

    pub fn ground() TextureWrapper {
        return .{
            .tag = .ground,
            .data = .{ .ground = {} },
        };
    }

    pub fn wall() TextureWrapper {
        return .{
            .tag = .wall,
            .data = .{ .wall = {} },
        };
    }

    pub fn barrel() TextureWrapper {
        return .{
            .tag = .barrel,
            .data = .{ .barrel = {} },
        };
    }

    pub fn player(team_color: TeamColor) TextureWrapper {
        return .{
            .tag = .player,
            .data = .{ .player = .{ .team_color = team_color } },
        };
    }

    pub fn dynamite(team_color: TeamColor) TextureWrapper {
        return .{
            .tag = .dynamite,
            .data = .{ .dynamite = .{ .team_color = team_color } },
        };
    }

    pub fn explosion(team_color: TeamColor, variant: ExplosionVariant) TextureWrapper {
        return .{
            .tag = .explosion,
            .data = .{ .explosion = .{
                .team_color = team_color,
                .variant = variant,
            } },
        };
    }

    pub fn eql(a: TextureWrapper, b: TextureWrapper) bool {
        if (a.tag != b.tag) return false;

        return switch (a.tag) {
            .ground, .wall, .barrel => true,
            .player => a.data.player.team_color == b.data.player.team_color,
            .dynamite => a.data.dynamite.team_color == b.data.dynamite.team_color,
            .explosion => a.data.explosion.team_color == b.data.explosion.team_color and a.data.explosion.variant == b.data.explosion.variant,
        };
    }

    pub fn hash(self: TextureWrapper) u64 {
        var hasher = std.hash.Wyhash.init(0);

        hasher.update(&[1]u8{@as(u8, @intFromEnum(self.tag))});

        switch (self.tag) {
            .ground, .wall, .barrel => {},
            .player => {
                hasher.update(&[1]u8{@as(u8, @intFromEnum(self.data.player.team_color))});
            },
            .dynamite => {
                hasher.update(&[1]u8{@as(u8, @intFromEnum(self.data.dynamite.team_color))});
            },
            .explosion => {
                hasher.update(&[2]u8{ @as(u8, @intFromEnum(self.data.explosion.team_color)), @as(u8, @intFromEnum(self.data.explosion.variant)) });
            },
        }

        return hasher.final();
    }
};

pub const TextureContext = struct {
    hash: *const fn (TextureWrapper) u64 = TextureWrapper.hash,
    eql: *const fn (TextureWrapper, TextureWrapper) bool = TextureWrapper.eql,
};
