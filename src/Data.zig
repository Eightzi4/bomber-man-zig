const std = @import("std");
const rl = @import("raylib");

const cons = @import("constants.zig");
const types = @import("types.zig");

pub const State = enum {
    initialization,
    menu,
    game,
    quit,
};

dbg_allocator: std.heap.DebugAllocator(.{}),
rand_gen: std.Random,
state: State,
team_colors: std.enums.EnumArray(types.Team, rl.Color),
textures: std.enums.EnumArray(types.Texture, rl.Texture2D),

pub fn init() @This() {
    var debug_allocator = std.heap.DebugAllocator(.{}){};

    return .{
        .dbg_allocator = debug_allocator,
        .rand_gen = D: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            var prng = std.Random.DefaultPrng.init(seed);

            break :D prng.random();
        },
        .state = .initialization,
        .team_colors = D: {
            const default_colors = std.enums.EnumFieldStruct(types.Team, rl.Color, null){
                .alpha = .blue,
                .beta = .red,
                .gamma = .green,
                .delta = .yellow,
            };

            break :D std.enums.EnumArray(types.Team, rl.Color).init(default_colors);
        },
        .textures = loadTextures(debug_allocator.allocator()),
    };
}

pub fn deinit(self: *@This()) void {
    unloadTextures(self.textures);
    _ = self.dbg_allocator.deinit();
}

fn loadTextures(allocator: std.mem.Allocator) std.enums.EnumArray(types.Texture, rl.Texture2D) {
    var dir = std.fs.cwd().openDir(cons.ASSET_DIRECTORY_PATH, .{ .iterate = true }) catch @panic("Failed to open assets directory!");
    defer dir.close();

    var textures = std.enums.EnumArray(types.Texture, rl.Texture2D).initUndefined();

    var file_iterator = dir.iterate();
    while (file_iterator.next() catch @panic("Directory iteration failed!")) |entry| {
        if (entry.kind != .file) @panic("Not an image file!");

        const ext = std.fs.path.extension(entry.name);
        if (!std.mem.eql(u8, ext, ".png")) @panic("Unsupported asset file type!");

        const texture_path = std.fs.path.joinZ(allocator, &.{ cons.ASSET_DIRECTORY_PATH, entry.name }) catch @panic("Out of memory!");
        defer allocator.free(texture_path);

        const texture = rl.loadTexture(texture_path) catch @panic("Failed to load texture!");
        rl.setTextureFilter(texture, rl.TextureFilter.point);

        textures.set(std.meta.stringToEnum(types.Texture, entry.name[0 .. entry.name.len - 4]) orelse @panic("Wrong asset name!"), texture);
    }

    return textures;
}

fn unloadTextures(textures: std.enums.EnumArray(types.Texture, rl.Texture2D)) void {
    for (textures.values) |texture| rl.unloadTexture(texture);
}
