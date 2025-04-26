pub const Vec2 = struct {
    x: i32,
    y: i32,
};

pub const TeamColor = enum(u2) {
    blue,
    red,
    yellow,
    green,
};

//TODO: Refactor
pub const Texture = enum {
    ground,
    wall,
    barrel,

    blue_player,
    red_player,

    blue_dynamite,
    red_dynamite,

    blue_horizontal_explosion,
    blue_vertical_explosion,
    blue_crossed_explosion,
    red_horizontal_explosion,
    red_vertical_explosion,
    red_crossed_explosion,

    pub fn isExplosion(self: @This()) bool {
        return @intFromEnum(self) >= @intFromEnum(Texture.blue_horizontal_explosion);
    }

    pub fn getTeamColor(self: @This()) TeamColor {
        return switch (self) {
            .blue_player, .blue_dynamite, .blue_horizontal_explosion, .blue_vertical_explosion, .blue_crossed_explosion => .blue,
            .red_player, .red_dynamite, .red_horizontal_explosion, .red_vertical_explosion, .red_crossed_explosion => .red,
            else => unreachable,
        };
    }
};

pub const Texture2 = packed union {
    Ground: void,
    Wall: void,
    Barrel: void,
    Player: packed struct { team_color: TeamColor },
    Dynamite: packed struct { team_color: TeamColor },
    Explosion: packed struct { team_color: TeamColor, variant: ExplosionVariant },
};

pub const ExplosionVariant = enum(u2) {
    horizontal,
    vertical,
    crossed,
};
