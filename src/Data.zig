const std = @import("std");
const rl = @import("raylib");

const cons = @import("constants.zig");
const types = @import("types.zig");
const Game = @import("Game.zig");
const Player = @import("Player.zig");
const Menu = @import("Menu.zig");

pub const State = enum {
    initialization,
    menu,
    game,
    quit,
};

dbg_allocator: std.heap.DebugAllocator(.{}),
prng: std.Random.Xoshiro256,
state: State,
team_colors: std.enums.EnumArray(types.Team, rl.Color),
textures: std.enums.EnumArray(types.Texture, rl.Texture2D),
original_ground_image: rl.Image,
cell_size: f32,
player_count: i32,
key_bindings: std.enums.EnumArray(types.Team, Player.Actions),

pub fn init() @This() {
    const cell_size = @as(f32, @floatFromInt(rl.getScreenHeight())) / cons.GRID_SIZE.y;
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    var textures = loadTextures(debug_allocator.allocator());
    const original_ground_image = rl.loadImageFromTexture(textures.get(.ground)) catch @panic("Failed to load ground image!");

    resizeGroundTexture(&textures, original_ground_image, cell_size);

    return .{
        .dbg_allocator = debug_allocator,
        .prng = D: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :D std.Random.DefaultPrng.init(seed);
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
        .textures = textures,
        .original_ground_image = original_ground_image,
        .cell_size = cell_size,
        .player_count = 2,
        .key_bindings = .init(.{
            .alpha = .{
                .movement = .init(.{
                    .left = .{ .binded_key = .a },
                    .right = .{ .binded_key = .d },
                    .down = .{ .binded_key = .s },
                    .up = .{ .binded_key = .w },
                }),
                .place_dynamite = .{ .binded_key = .space },
            },
            .beta = .{
                .movement = .init(.{
                    .left = .{ .binded_key = .left },
                    .right = .{ .binded_key = .right },
                    .down = .{ .binded_key = .down },
                    .up = .{ .binded_key = .up },
                }),
                .place_dynamite = .{ .binded_key = .enter },
            },
            .gamma = .{
                .movement = .init(.{
                    .left = .{ .binded_key = .f },
                    .right = .{ .binded_key = .h },
                    .down = .{ .binded_key = .g },
                    .up = .{ .binded_key = .t },
                }),
                .place_dynamite = .{ .binded_key = .y },
            },
            .delta = .{
                .movement = .init(.{
                    .left = .{ .binded_key = .j },
                    .right = .{ .binded_key = .l },
                    .down = .{ .binded_key = .k },
                    .up = .{ .binded_key = .i },
                }),
                .place_dynamite = .{ .binded_key = .o },
            },
        }),
    };
}

pub fn deinit(self: *@This()) void {
    unloadTextures(self.textures);
    _ = self.dbg_allocator.deinit();
}

pub fn update(self: *@This()) void {
    if (rl.isWindowResized()) {
        const field_width = (@as(f32, @floatFromInt(rl.getScreenWidth())) - self.cell_size * cons.GUI_SIZE) / cons.GRID_SIZE.x;
        const field_height = @as(f32, @floatFromInt(rl.getScreenHeight())) / cons.GRID_SIZE.y;
        self.cell_size = @max(@min(field_width, field_height), 1);

        resizeGroundTexture(&self.textures, self.original_ground_image, self.cell_size);
    }
}

pub fn run(self: *@This()) void {
    while (!rl.windowShouldClose()) {
        self.state = switch (self.state) {
            .initialization => .menu,
            .menu => self.runMenu(),
            .game => self.runGame(),
            .quit => return,
        };
    }
}

pub fn runMenu(data: *@This()) State {
    var menu = Menu.init(data);

    while (!rl.windowShouldClose()) {
        if (menu.exit_game) return .quit;
        if (menu.play_game) return .game;

        data.update();
        menu.update();
        menu.draw();
    }

    return .quit;
}

pub fn runGame(data: *@This()) State {
    var game = Game.init(data);
    defer game.deinit();

    for (0..@intCast(data.player_count)) |i| {
        const team: types.Team = @enumFromInt(i);

        game.opt_players.set(team, .init(
            cons.PLAYER_START_POSITIONS[i],
            game.world_id,
            data.key_bindings.get(team),
            &game.team_textures.getPtr(team).player_textures,
        ));
    }

    while (!rl.windowShouldClose()) {
        if (rl.isKeyDown(.escape)) return .menu;

        data.update();
        game.update();
        game.draw();
    }

    return .quit;
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

fn resizeGroundTexture(textures: *std.enums.EnumArray(types.Texture, rl.Texture2D), original_ground_image: rl.Image, cell_size: f32) void {
    var img = original_ground_image.copy();
    defer rl.unloadImage(img);
    img.resizeNN(@intFromFloat(cell_size), @intFromFloat(cell_size));

    rl.unloadTexture(textures.get(.ground));
    textures.set(.ground, rl.loadTextureFromImage(img) catch @panic("Failed to load ground texture"));
}
