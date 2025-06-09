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
settings: types.GameSettings,

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
        .settings = .{
            .player_count = 2, // Initialize player count
            .player_configs = .{
                // Player 1
                .{ .team_color = .blue, .key_bindings = .init(.{ .left = .a, .right = .d, .up = .w, .down = .s }) },
                // Player 2
                .{ .team_color = .red, .key_bindings = .init(.{ .left = .left, .right = .right, .up = .up, .down = .down }) },
                // Player 3
                .{ .team_color = .green, .key_bindings = .init(.{ .left = .j, .right = .l, .up = .i, .down = .k }) },
                // Player 4 - THE FIX
                // We ensure every key binding has a default safe value of .null.
                .{ .team_color = .yellow, .key_bindings = .init(.{ .left = .j, .right = .l, .up = .i, .down = .k }) },
            },
        },
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
    var menu = Menu.init(&data.textures, &data.settings);

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

    game.opt_players.set(.alpha, .init(
        .{ .x = 1, .y = 1 },
        game.world_id,
        .{
            .movement = .init(.{
                .left = .{ .binded_key = .a },
                .right = .{ .binded_key = .d },
                .up = .{ .binded_key = .w },
                .down = .{ .binded_key = .s },
            }),
            .place_dynamite = .{ .binded_key = .space },
        },
        &game.team_textures.get(.alpha).player_textures,
    ));

    game.opt_players.set(.beta, .init(
        .{ .x = 13, .y = 11 },
        game.world_id,
        .{
            .movement = .init(.{
                .left = .{ .binded_key = .left },
                .right = .{ .binded_key = .right },
                .up = .{ .binded_key = .up },
                .down = .{ .binded_key = .down },
            }),
            .place_dynamite = .{ .binded_key = .enter },
        },
        &game.team_textures.get(.beta).player_textures,
    ));

    game.opt_players.set(.gamma, .init(
        .{ .x = 1, .y = 11 },
        game.world_id,
        .{
            .movement = .init(.{
                .left = .{ .binded_key = .eight },
                .right = .{ .binded_key = .six },
                .up = .{ .binded_key = .eight },
                .down = .{ .binded_key = .two },
            }),
            .place_dynamite = .{ .binded_key = .five },
        },
        &game.team_textures.get(.gamma).player_textures,
    ));

    game.opt_players.set(.delta, .init(
        .{ .x = 1, .y = 11 },
        game.world_id,
        .{
            .movement = .init(.{
                .left = .{ .binded_key = .z },
                .right = .{ .binded_key = .u },
                .up = .{ .binded_key = .i },
                .down = .{ .binded_key = .o },
            }),
            .place_dynamite = .{ .binded_key = .p },
        },
        &game.team_textures.get(.delta).player_textures,
    ));

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
