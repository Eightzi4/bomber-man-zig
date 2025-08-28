const std = @import("std");

pub const TEXTURES = D: {
    var textures = std.enums.EnumArray(Texture, []const u8).initUndefined();

    for (std.enums.values(Texture)) |texture| textures.set(texture, @embedFile("textures/" ++ @tagName(texture) ++ ".png"));

    break :D textures;
};

pub const SHADER = @embedFile("shaders/mask.fs");

pub const Texture = D: {
    const texture_file_names = @import("build_options").texture_file_names;

    var fields: [texture_file_names.len]std.builtin.Type.EnumField = undefined;

    for (texture_file_names, 0..) |texture_name, i| {
        fields[i] = .{
            .name = texture_name,
            .value = i,
        };
    }

    break :D @Type(.{ .@"enum" = .{
        .fields = &fields,
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
        .tag_type = std.math.IntFittingRange(0, texture_file_names.len),
    } });
};
