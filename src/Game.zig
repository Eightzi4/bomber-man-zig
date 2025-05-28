const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const funcs = @import("functions.zig");
const cons = @import("constants.zig");
const Player = @import("Player.zig");

pub const Cell = struct {
    texture: types.Texture,
    body_id: ?b2.b2BodyId,
};

world_id: b2.b2WorldId,
cell_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]Cell,
textures: types.TextureHashMap,
optional_players: [4]?Player,
accumulator: f32,

pub fn init(allocator: std.mem.Allocator, random: std.Random) @This() {
    const world_id = b2.b2CreateWorld(&b2.b2DefaultWorldDef());
    return .{
        .world_id = world_id,
        .cell_grid = generateCellGrid(random, world_id),
        .textures = loadTextures(allocator),
        .optional_players = .{null} ** 4,
        .accumulator = 0,
    };
}

pub fn deinit(self: *@This()) void {
    unloadTextures(self.textures);
    self.textures.deinit();
}

pub fn update(self: *@This()) void {
    const delta_time = rl.getFrameTime();

    self.accumulator += delta_time;

    while (self.accumulator >= cons.PHYSICS_TIMESTEP) {
        fixedUpdate(self);

        self.accumulator -= cons.PHYSICS_TIMESTEP;
    }

    for (&self.optional_players) |*optional_player| if (optional_player.*) |*player| {
        player.update();
    };
}

fn fixedUpdate(self: *@This()) void {
    for (&self.optional_players) |*p| if (p.*) |*player| {
        player.fixedUpdate();
    };

    handleExplosions(self);

    b2.b2World_Step(self.world_id, cons.PHYSICS_TIMESTEP, cons.PHYSICS_SUBSTEP_COUNT);
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    self.drawBackground();

    const alpha = self.accumulator / cons.PHYSICS_TIMESTEP;

    for (&self.optional_players) |*optional_player| if (optional_player.*) |*player| {
        player.draw(self.textures, alpha);
    };

    drawGui(self);

    //rl.setTextureFilter(self.textures.get(.idk()) orelse @panic(""), rl.TextureFilter.point); // might need this
    //const mask_shader = rl.loadShader(null, "mask.fs") catch @panic("Failed to load shader!");
    //rl.beginShaderMode(mask_shader);
    //rl.setShaderValue(mask_shader, rl.getShaderLocation(mask_shader, "color"), // Get the uniform location
    //    &[3]f32{ 0.0, 1.0, 0.0 }, // Pointer to the color data
    //    rl.ShaderUniformDataType.vec3 // Specify vec4 type
    //); // Pass player color
    //rl.drawTexture(self.textures.get(.idk()) orelse @panic(""), 0, 0, .white); // WHITE preserves original alpha
    //rl.endShaderMode();
}

fn drawGui(self: *@This()) void {
    const padding = cons.GUI_SIZE / 20;
    const player_gui_size = types.Vec2{ .x = cons.GUI_SIZE - padding * 2, .y = (cons.WINDOW_SIZE.y - cons.GUI_SIZE / 2) / 4 - padding * 2 };
    const name = "negr bagr";

    rl.drawRectangle(0, 0, cons.GUI_SIZE, cons.WINDOW_SIZE.y, .gray);

    for (&self.optional_players, 0..) |*optional_player, i| if (optional_player.*) |player| {
        const position = types.Vec2{ .x = padding, .y = padding + (player_gui_size.y + padding) * @as(i32, @intCast(i)) };

        // Background
        funcs.drawRectangleWithOutline(
            .{ .x = position.x, .y = position.y },
            player_gui_size,
            switch (player.team_color) {
                .red => rl.Color{ .r = 255, .g = 200, .b = 200, .a = 255 },
                .blue => rl.Color{ .r = 200, .g = 200, .b = 255, .a = 255 },
                .green => rl.Color{ .r = 200, .g = 255, .b = 200, .a = 255 },
                .yellow => rl.Color{ .r = 255, .g = 255, .b = 200, .a = 255 },
            },
            cons.CELL_SIZE / 20,
            .black,
        );

        // Player icon
        const player_texture = self.textures.get(.player(player.team_color)) orelse @panic("Missing player texture");

        rl.drawTexture(player_texture, position.x + padding, position.y + padding, .white);

        // Player name
        var text_size: i32 = cons.CELL_SIZE;
        var text_width = rl.measureText(name, text_size);

        while (text_width > cons.CELL_SIZE * 2 and text_size > 1) : (text_size -= 1) text_width = rl.measureText(name, text_size);

        rl.drawText(name, padding * 3 + player_texture.width, position.y + padding, text_size, .black);

        // Health
        for (0..cons.MAX_HEALTH) |j| {
            if (j < player.health) {
                rl.drawCircle(
                    padding * 3 + player_texture.width + cons.CELL_SIZE / 4 + @divTrunc(player_gui_size.x - padding * 2 - player_texture.width, 3) * @as(i32, @intCast(j)),
                    position.y + player_texture.height - padding * 2 + cons.CELL_SIZE / 4,
                    cons.CELL_SIZE / 4,
                    if (player.invincibility_timer > 0) .gray else .red,
                );
            } else {
                rl.drawLine(
                    padding * 3 + player_texture.width + @divTrunc(player_gui_size.x - padding * 2 - player_texture.width, 3) * @as(i32, @intCast(j)),
                    position.y + player_texture.height - padding * 2,
                    padding * 3 + player_texture.width + cons.CELL_SIZE / 2 + @divTrunc(player_gui_size.x - padding * 2 - player_texture.width, 3) * @as(i32, @intCast(j)),
                    position.y + player_texture.height - padding * 2 + cons.CELL_SIZE / 2,
                    .black,
                );

                rl.drawLine(
                    padding * 3 + player_texture.width + @divTrunc(player_gui_size.x - padding * 2 - player_texture.width, 3) * @as(i32, @intCast(j)),
                    position.y + player_texture.height - padding * 2 + cons.CELL_SIZE / 2,
                    padding * 3 + player_texture.width + cons.CELL_SIZE / 2 + @divTrunc(player_gui_size.x - padding * 2 - player_texture.width, 3) * @as(i32, @intCast(j)),
                    position.y + player_texture.height - padding * 2,
                    .black,
                );
            }
        }
    };
}

fn generateCellGrid(random: std.Random, world_id: b2.b2WorldId) [cons.GRID_SIZE.y][cons.GRID_SIZE.x]Cell {
    var cell_grid = [_][cons.GRID_SIZE.x]Cell{[_]Cell{
        Cell{
            .texture = .ground(),
            .body_id = null,
        },
    } ** cons.GRID_SIZE.x} ** cons.GRID_SIZE.y;

    const createCollider = struct {
        fn createCollider(x: usize, y: usize, world_id_2: b2.b2WorldId) b2.b2BodyId {
            var body_def = b2.b2DefaultBodyDef();
            body_def.position = .{
                .x = @floatFromInt(cons.GUI_SIZE + cons.CELL_SIZE * x + cons.CELL_SIZE / 2),
                .y = @floatFromInt(cons.CELL_SIZE * y + cons.CELL_SIZE / 2),
            };

            const body_id = b2.b2CreateBody(world_id_2, &body_def);

            _ = b2.b2CreatePolygonShape(
                body_id,
                &b2.b2DefaultShapeDef(),
                &b2.b2MakeBox(cons.CELL_SIZE / 2, cons.CELL_SIZE / 2),
            );

            return body_id;
        }
    }.createCollider;

    for (&cell_grid, 0..) |*row, y| {
        for (row, 0..) |*cell, x| {
            if (y % (cons.GRID_SIZE.y - 1) == 0 or x % (cons.GRID_SIZE.x - 1) == 0 or x % 2 == 0 and y % 2 == 0) {
                cell.texture = .wall();
                cell.body_id = createCollider(x, y, world_id);
            } else {
                const max_y = cons.GRID_SIZE.y - y - 1;
                const max_x = cons.GRID_SIZE.x - x - 1;

                if (!(@min(x, max_x) < 4 and @min(y, max_y) < 4 and @min(x, max_x) + @min(y, max_y) < 5) and
                    (random.boolean() or random.boolean()))
                {
                    cell.texture = .barrel();
                    cell.body_id = createCollider(x, y, world_id);
                }
            }
        }
    }

    return cell_grid;
}

fn loadTextures(allocator: std.mem.Allocator) types.TextureHashMap {
    var dir = std.fs.cwd().openDir(cons.ASSET_DIRECTORY_PATH, .{ .iterate = true }) catch {
        @panic("Failed to open assets directory!");
    };
    defer dir.close();

    var textures = types.TextureHashMap.initContext(allocator, .{});

    var file_iterator = dir.iterate();
    while (file_iterator.next() catch @panic("Directory iteration failed!")) |entry| {
        if (entry.kind != .file) continue;

        const ext = std.fs.path.extension(entry.name);
        if (!std.mem.eql(u8, ext, ".png")) @panic("Unsupported asset file type!");

        const file_name = entry.name[0 .. entry.name.len - ext.len];
        var file_name_parts_iterator = std.mem.splitAny(u8, file_name, "_");

        const key: types.Texture = switch (std.meta.stringToEnum(std.meta.FieldEnum(types.TextureData), file_name_parts_iterator.next() orelse @panic("Asset file has no name!")).?) {
            .ground => .ground(),
            .wall => .wall(),
            .barrel => .barrel(),
            .player => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Couldn't parse string to TeamColor! Bad naming?")).?;

                break :D .player(team_color);
            },
            .dynamite => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Couldn't parse string to TeamColor! Bad naming?")).?;

                break :D .dynamite(team_color);
            },
            .explosion => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Couldn't parse string to TeamColor! Bad naming?")).?;
                const variant = std.meta.stringToEnum(types.ExplosionVariant, file_name_parts_iterator.next() orelse @panic("Couldn't parse string to ExplosionVariant! Bad naming?")).?;

                break :D .explosion(team_color, variant);
            },
            .idk => .idk(),
        };

        const texture_path = std.fs.path.joinZ(allocator, &.{ cons.ASSET_DIRECTORY_PATH, entry.name }) catch @panic("Out of memory!");
        defer allocator.free(texture_path);

        var image = rl.loadImage(texture_path) catch @panic("Failed to load image!");
        defer rl.unloadImage(image);
        image.resize(cons.CELL_SIZE, cons.CELL_SIZE);

        const texture = rl.loadTextureFromImage(image) catch @panic("Failed to create texture!");

        textures.put(key, texture) catch @panic("Out of memory!");
    }

    return textures;
}

fn unloadTextures(textures: types.TextureHashMap) void {
    var iterator = textures.iterator();
    while (iterator.next()) |texture| rl.unloadTexture(texture.value_ptr.*);
}

fn drawBackground(self: *@This()) void {
    for (0..cons.GRID_SIZE.y) |y| {
        for (0..cons.GRID_SIZE.x) |x| {
            const pos = types.Vec2{
                .x = cons.GUI_SIZE + cons.CELL_SIZE * @as(i32, @intCast(x)),
                .y = cons.CELL_SIZE * @as(i32, @intCast(y)),
            };

            rl.drawTexture(
                self.textures.get(self.cell_grid[y][x].texture) orelse @panic("HashMap doesn't contain this key!"),
                pos.x,
                pos.y,
                rl.Color.white,
            );
        }
    }
}

// TODO: Refactor into smaller functions
fn handleExplosions(self: *@This()) void {
    for (&self.optional_players) |*optional_player| if (optional_player.*) |*player| {
        for (&player.optional_dynamites) |*optional_dynamite| if (optional_dynamite.*) |*dynamite| {
            if (dynamite.timer > 0) {
                if (dynamite.state == .exploding) {
                    const grid_position = funcs.gridPositionFromPixelPosition(dynamite.position);

                    D: for (&self.optional_players) |*optional_player_2| if (optional_player_2.*) |*player_2| {
                        const player_2_position = b2.b2Body_GetPosition(player_2.body_id);
                        const player_2_grid_position = types.Vec2{
                            .x = @divFloor(@as(i32, @intFromFloat(player_2_position.x - cons.GUI_SIZE)), cons.CELL_SIZE),
                            .y = @divFloor(@as(i32, @intFromFloat(player_2_position.y)), cons.CELL_SIZE),
                        };

                        if (player_2_grid_position.x == grid_position.x and player_2_grid_position.y == grid_position.y) {
                            player_2.hurt();

                            break :D;
                        }
                    };

                    for (cons.DIRECTIONS) |dir| {
                        for (1..dynamite.radius) |offset| {
                            const cell_position = grid_position.add(dir.mul_scalar(@intCast(offset)));

                            D: for (&self.optional_players) |*optional_player_2| if (optional_player_2.*) |*player_2| {
                                const player_2_position = b2.b2Body_GetPosition(player_2.body_id);
                                const player_2_grid_position = types.Vec2{
                                    .x = @divFloor(@as(i32, @intFromFloat(player_2_position.x - cons.GUI_SIZE)), cons.CELL_SIZE),
                                    .y = @divFloor(@as(i32, @intFromFloat(player_2_position.y)), cons.CELL_SIZE),
                                };

                                if (player_2_grid_position.x == cell_position.x and player_2_grid_position.y == cell_position.y) {
                                    player_2.hurt();

                                    break :D;
                                }
                            };
                        }
                    }
                }
            } else {
                const grid_position = funcs.gridPositionFromPixelPosition(dynamite.position);

                if (dynamite.state == .idle) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture = .explosion(dynamite.team_color, .crossed);

                    for (cons.DIRECTIONS, 0..) |dir, i| {
                        for (1..dynamite.radius) |offset| {
                            const cell_position = grid_position.add(dir.mul_scalar(@intCast(offset)));

                            var cell = &self.cell_grid[@intCast(cell_position.y)][@intCast(cell_position.x)];
                            if (cell.texture.tag != .wall and !(cell.texture.tag == .explosion and cell.texture.data.explosion.variant == .crossed)) {
                                cell.texture = .explosion(
                                    dynamite.team_color,
                                    D: {
                                        const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;
                                        if (cell.texture.tag == .explosion and cell.texture.data.explosion.team_color == dynamite.team_color and cell.texture.data.explosion.variant != variant)
                                            break :D .crossed;

                                        break :D variant;
                                    },
                                );

                                if (cell.body_id) |body_id| {
                                    b2.b2DestroyBody(body_id);
                                    cell.body_id = null;

                                    break;
                                } else {
                                    D: for (&self.optional_players) |*optional_player_2| if (optional_player_2.*) |*player_2| {
                                        for (&player_2.optional_dynamites) |*optional_dynamite_2| if (optional_dynamite_2.*) |*dynamite_2| {
                                            if (funcs.gridPositionFromPixelPosition(dynamite_2.position).eql(cell_position)) {
                                                dynamite_2.timer = 0;

                                                break :D;
                                            }
                                        };
                                    };
                                }
                            } else break;
                        }
                    }
                } else if (dynamite.state == .exploded) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture.tag = .ground;

                    for (cons.DIRECTIONS) |dir| {
                        for (1..dynamite.radius) |offset| {
                            const cell_position = grid_position.add(dir.mul_scalar(@intCast(offset)));
                            var cell = &self.cell_grid[@intCast(cell_position.y)][@intCast(cell_position.x)];

                            if (cell.texture.tag != .wall) {
                                if (cell.texture.tag == .explosion) cell.texture.tag = .ground;
                            } else break;
                        }
                    }

                    optional_dynamite.* = null;
                }

                dynamite.switchState();
            }
        };
    };
}
