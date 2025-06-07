const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const funcs = @import("functions.zig");
const cons = @import("constants.zig");
const Player = @import("Player.zig");
const Data = @import("Data.zig");

world_id: b2.b2WorldId,
cell_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]types.Cell,
explosion_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]?types.ExplosionVariant,
team_textures: std.enums.EnumArray(types.Team, types.TeamTextures),
opt_players: std.enums.EnumArray(types.Team, ?Player),
accumulator: f32,
textures: *const std.enums.EnumArray(types.Texture, rl.Texture2D),

pub fn init(data: *Data) @This() {
    const world_id = b2.b2CreateWorld(&b2.b2DefaultWorldDef());

    return .{
        .world_id = world_id,
        .cell_grid = generateCellGrid(data.rand_gen, world_id),
        .explosion_grid = @splat(@splat(null)),
        .team_textures = createTeamTextures(data.team_colors, data.textures),
        .opt_players = .initFill(null),
        .accumulator = 0,
        .textures = &data.textures,
    };
}

pub fn update(self: *@This()) void {
    const delta_time = rl.getFrameTime();

    self.accumulator += delta_time;

    while (self.accumulator >= cons.PHYSICS_TIMESTEP) {
        fixedUpdate(self);

        self.accumulator -= cons.PHYSICS_TIMESTEP;
    }

    for (&self.opt_players.values) |*opt_player| if (opt_player.*) |*player| {
        player.update();
    };
}

fn fixedUpdate(self: *@This()) void {
    var iterator = self.opt_players.iterator();

    while (iterator.next()) |opt_player| if (opt_player.value.*) |*player| {
        player.fixedUpdate();

        if (player.actions.get(.place_dynamite).cached_input) {
            const position = b2.b2Body_GetPosition(player.body_id);
            const aligned_position = b2.b2Vec2{
                .x = @divTrunc(position.x, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
                .y = @divTrunc(position.y, cons.CELL_SIZE) * cons.CELL_SIZE + cons.CELL_SIZE / 2,
            };
            const grid_position = funcs.gridPositionFromPixelPosition(aligned_position);
            self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)] = .initDynamite(opt_player.key);
            player.actions.getPtr(.place_dynamite).cached_input = false;
        }
    };

    //handleExplosions(self);
    decayExplosions(self);
    updateDynamitesAndExplosions(self);

    b2.b2World_Step(self.world_id, cons.PHYSICS_TIMESTEP, cons.PHYSICS_SUBSTEP_COUNT);
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    self.drawBackground();

    const alpha = self.accumulator / cons.PHYSICS_TIMESTEP;

    for (&self.opt_players.values) |*opt_player| if (opt_player.*) |*player| {
        player.draw(alpha);
    };

    //drawGui(self);
}

fn drawGui(self: *@This()) void {
    const padding = cons.GUI_SIZE / 20;
    const player_gui_size = types.Vec2{ .x = cons.GUI_SIZE - padding * 2, .y = (cons.WINDOW_SIZE.y - cons.GUI_SIZE / 2) / 4 - padding * 2 };
    const name = "negr bagr";

    rl.drawRectangle(0, 0, cons.GUI_SIZE, cons.WINDOW_SIZE.y, .gray);

    for (&self.opt_players.values, 0..) |*opt_player, i| if (opt_player.*) |player| {
        const position = types.Vec2{ .x = padding, .y = padding + (player_gui_size.y + padding) * @as(i32, @intCast(i)) };

        // Background
        funcs.drawRectangleWithOutline(
            .{ .x = position.x, .y = position.y },
            player_gui_size,
            .blue,
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

fn generateCellGrid(random: std.Random, world_id: b2.b2WorldId) [cons.GRID_SIZE.y][cons.GRID_SIZE.x]types.Cell {
    var cell_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]types.Cell = @splat(@splat(.initGround()));

    for (&cell_grid, 0..) |*row, y| {
        for (row, 0..) |*cell, x| {
            if (y % (cons.GRID_SIZE.y - 1) == 0 or x % (cons.GRID_SIZE.x - 1) == 0 or x % 2 == 0 and y % 2 == 0) {
                cell.* = .initWall(@intCast(x), @intCast(y), world_id);
            } else {
                const max_y = cons.GRID_SIZE.y - y - 1;
                const max_x = cons.GRID_SIZE.x - x - 1;

                if (!(@min(x, max_x) < 4 and @min(y, max_y) < 4 and @min(x, max_x) + @min(y, max_y) < 5) and
                    (random.boolean() or random.boolean()))
                {
                    cell.* = .initBarrel(@intCast(x), @intCast(y), world_id);
                }
            }
        }
    }

    return cell_grid;
}

fn createTeamTextures(team_colors: std.enums.EnumArray(types.Team, rl.Color), textures: std.enums.EnumArray(types.Texture, rl.Texture2D)) std.enums.EnumArray(types.Team, types.TeamTextures) {
    var team_textures = std.enums.EnumArray(types.Team, types.TeamTextures).initUndefined();
    const shader = rl.loadShader(null, "mask.fs") catch @panic("Failed to load shader!");
    defer rl.unloadShader(shader);

    for (std.enums.values(types.Team)) |team| {
        const color = team_colors.get(team);
        const dynamite_textures = [_]rl.Texture2D{
            applyShaderToTexture(shader, color, textures.get(.dynamite_1)),
            applyShaderToTexture(shader, color, textures.get(.dynamite_2)),
        };
        const explosion_textures = [_]rl.Texture2D{
            applyShaderToTexture(shader, color, textures.get(.explosion_1)),
            applyShaderToTexture(shader, color, textures.get(.explosion_2)),
        };
        const player_textures = types.PlayerTextures{
            .side = .{
                applyShaderToTexture(shader, color, textures.get(.player_side_1)),
                applyShaderToTexture(shader, color, textures.get(.player_side_2)),
                applyShaderToTexture(shader, color, textures.get(.player_side_3)),
            },
            .down = .{
                applyShaderToTexture(shader, color, textures.get(.player_down_1)),
                applyShaderToTexture(shader, team_colors.get(team), textures.get(.player_down_2)),
            },
            .up = .{
                applyShaderToTexture(shader, color, textures.get(.player_up_1)),
                applyShaderToTexture(shader, color, textures.get(.player_up_2)),
            },
        };

        team_textures.set(team, .{ .dynamite_textures = dynamite_textures, .explosion_textures = explosion_textures, .player_textures = player_textures });
    }

    return team_textures;
}

fn applyShaderToTexture(shader: rl.Shader, color: rl.Color, texture: rl.Texture2D) rl.Texture2D {
    var result: rl.Texture2D = undefined;
    const target = rl.loadRenderTexture(texture.width, texture.height) catch @panic("Failed to load render texture!");
    defer rl.unloadRenderTexture(target);

    rl.beginTextureMode(target);
    rl.clearBackground(.blank);

    rl.beginShaderMode(shader);
    rl.setShaderValue(shader, rl.getShaderLocation(shader, "color"), &color.normalize(), rl.ShaderUniformDataType.vec4);
    rl.drawTexture(texture, 0, 0, .white);
    rl.endShaderMode();
    rl.endTextureMode();

    var image = rl.loadImageFromTexture(target.texture) catch @panic("Failed to load image from texture!");
    defer rl.unloadImage(image);
    image.flipVertical();

    result = rl.loadTextureFromImage(image) catch @panic("Failed to load texture from image!");
    return result;
}

fn drawBackground(self: *@This()) void {
    const ground_texture = self.textures.get(.ground);

    rl.setTextureWrap(ground_texture, rl.TextureWrap.repeat);

    const dst = rl.Rectangle{
        .x = cons.GUI_SIZE,
        .y = 0.0,
        .width = cons.GRID_SIZE.x * cons.CELL_SIZE,
        .height = cons.GRID_SIZE.y * cons.CELL_SIZE,
    };

    const src = rl.Rectangle{
        .x = 0.0,
        .y = 0.0,
        .width = dst.width,
        .height = dst.height,
    };

    const origin = rl.Vector2{ .x = 0.0, .y = 0.0 };

    rl.drawTexturePro(
        ground_texture,
        src,
        dst,
        origin,
        0.0,
        .white,
    );

    for (0..cons.GRID_SIZE.y) |y| {
        for (0..cons.GRID_SIZE.x) |x| {
            const cell = self.cell_grid[y][x];
            const active_tag = cell.tag;

            switch (active_tag) {
                .ground => {},
                .wall, .death_wall, .barrel => {
                    funcs.drawGridTexture(self.textures.get(active_tag), .{ .x = @intCast(x), .y = @intCast(y) });
                },
                .explosion_1, .explosion_2 => {
                    const texture = self.team_textures.get(cell.variant.explosion_1.team).explosion_textures[@intFromBool(cell.variant.explosion_1.variant == .crossed)];

                    if (cell.variant.explosion_1.variant == .vertical) {
                        const pos = b2.b2Vec2{
                            .x = @floatFromInt(cons.GUI_SIZE + cons.CELL_SIZE * x + cons.CELL_SIZE / 2),
                            .y = @floatFromInt(cons.CELL_SIZE * y + cons.CELL_SIZE / 2),
                        };

                        funcs.drawCenteredTexture(texture, pos, 90);
                    } else {
                        funcs.drawGridTexture(texture, .{ .x = @intCast(x), .y = @intCast(y) });
                    }
                },
                .dynamite_1, .dynamite_2 => {
                    const texture = self.team_textures.get(cell.variant.dynamite_1.team).dynamite_textures[@intFromBool(active_tag == .dynamite_2)];

                    funcs.drawGridTexture(texture, .{ .x = @intCast(x), .y = @intCast(y) });
                },
                else => unreachable,
            }
        }
    }
}

fn hurtPlayersInsideExplosion(self: *@This()) void {
    var player_grid_positions: std.enums.EnumArray(types.Team, types.Vec2) = undefined;
    var iterator = self.opt_players.iterator();

    while (iterator.next()) |opt_player| if (opt_player.value.*) |*player| {
        player_grid_positions.set(opt_player.key, funcs.gridPositionFromPixelPosition2(b2.b2Body_GetPosition(player.body_id)));
    };
}

fn updateDynamitesAndExplosions(self: *@This()) void {
    for (0..cons.GRID_SIZE.y) |y| {
        for (0..cons.GRID_SIZE.x) |x| {
            var cell = &self.cell_grid[y][x];
            const active_tag = cell.tag;

            switch (active_tag) {
                .dynamite_2 => {
                    if (cell.variant.dynamite_1.timer > 0) {
                        cell.variant.dynamite_1.update();
                        break;
                    }

                    for (cons.DIRECTIONS, 0..) |dir, i| {
                        D: for (1..cell.variant.dynamite_1.radius) |offset| {
                            const grid_pos = types.Vec2{
                                .x = @as(i32, @intCast(x)) + dir.x * @as(i32, @intCast(offset)),
                                .y = @as(i32, @intCast(y)) + dir.y * @as(i32, @intCast(offset)),
                            };

                            var cell_in_radius = &self.cell_grid[@intCast(grid_pos.y)][@intCast(grid_pos.x)];
                            const cell_in_radius_active_tag = cell_in_radius.tag;

                            switch (cell_in_radius_active_tag) {
                                .wall, .death_wall, .explosion_2 => break,
                                .dynamite_1, .dynamite_2 => {
                                    cell_in_radius.variant.dynamite_1.timer = 0;

                                    break;
                                },
                                .ground, .barrel, .explosion_1 => {
                                    defer cell_in_radius.* = .initExplosion(
                                        cell.variant.dynamite_1.team,
                                        O: {
                                            const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;
                                            if (cell_in_radius_active_tag == .explosion_1 and cell_in_radius.variant.explosion_1.team == cell.variant.dynamite_1.team and cell_in_radius.variant.explosion_1.variant != variant)
                                                break :O .crossed;

                                            break :O variant;
                                        },
                                    );

                                    if (cell_in_radius_active_tag == .barrel) {
                                        b2.b2DestroyBody(cell_in_radius.variant.barrel.body_id);
                                        break :D;
                                    }
                                },
                                else => unreachable,
                            }
                        }
                    }

                    cell.* = .initExplosion(cell.variant.dynamite_1.team, .crossed);
                },
                .dynamite_1 => {
                    cell.variant.dynamite_1.update();
                    if (cell.variant.dynamite_1.timer < 1) cell.tag = .dynamite_2;
                },
                else => continue,
            }
        }
    }
}

fn decayExplosions(self: *@This()) void {
    for (0..cons.GRID_SIZE.y) |y| {
        for (0..cons.GRID_SIZE.x) |x| {
            var cell = &self.cell_grid[y][x];

            if (cell.tag == .explosion_1 or cell.tag == .explosion_2) {
                cell.variant.explosion_1.timer -= cons.PHYSICS_TIMESTEP;

                if (cell.variant.explosion_1.timer < 0) cell.* = .initGround();
            }
        }
    }
}

// TODO: Refactor into smaller functions
fn handleExplosions(self: *@This()) void {
    for (&self.opt_players.values) |*opt_player| if (opt_player.*) |*player| {
        for (&player.opt_dynamites) |*opt_dynamite| if (opt_dynamite.*) |*dynamite| {
            if (dynamite.timer > 0) {
                if (dynamite.state == .exploding) {
                    const grid_position = funcs.gridPositionFromPixelPosition(dynamite.position);

                    D: for (&self.opt_players) |*opt_player_2| if (opt_player_2.*) |*player_2| {
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

                            D: for (&self.opt_players) |*opt_player_2| if (opt_player_2.*) |*player_2| {
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
                                    D: for (&self.opt_players) |*opt_player_2| if (opt_player_2.*) |*player_2| {
                                        for (&player_2.opt_dynamites) |*opt_dynamite_2| if (opt_dynamite_2.*) |*dynamite_2| {
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

                    opt_dynamite.* = null;
                }

                dynamite.switchState();
            }
        };
    };
}
