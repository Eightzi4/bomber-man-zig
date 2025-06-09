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
team_textures: std.enums.EnumArray(types.Team, types.TeamTextures),
opt_players: std.enums.EnumArray(types.Team, ?Player),
accumulator: f32,
textures: *const std.enums.EnumArray(types.Texture, rl.Texture2D),
cell_size: *const f32,
data: *Data,

pub fn init(data: *Data) @This() {
    var world_def = b2.b2DefaultWorldDef();
    world_def.gravity = b2.b2Vec2{ .x = 0.0, .y = 0.0 };

    const world_id = b2.b2CreateWorld(&world_def);

    return .{
        .world_id = world_id,
        .cell_grid = generateCellGrid(data.prng.random(), world_id),
        .team_textures = createTeamTextures(data.team_colors, data.textures),
        .opt_players = .initFill(null),
        .accumulator = 0,
        .textures = &data.textures,
        .cell_size = &data.cell_size,
        .data = data,
    };
}

pub fn deinit(self: *@This()) void {
    b2.b2DestroyWorld(self.world_id);

    for (self.team_textures.values) |team_textures| {
        for (team_textures.player_textures.side) |texture| {
            rl.unloadTexture(texture);
        }
        for (team_textures.player_textures.up) |texture| {
            rl.unloadTexture(texture);
        }
        for (team_textures.player_textures.down) |texture| {
            rl.unloadTexture(texture);
        }

        for (team_textures.dynamite_textures) |texture| {
            rl.unloadTexture(texture);
        }

        for (team_textures.explosion_textures) |texture| {
            rl.unloadTexture(texture);
        }
    }
}

pub fn update(self: *@This()) void {
    const delta_time = rl.getFrameTime();

    self.accumulator += delta_time;

    while (self.accumulator >= cons.PHYSICS_TIMESTEP) {
        fixedUpdate(self);

        self.accumulator -= cons.PHYSICS_TIMESTEP;
    }

    for (&self.opt_players.values) |*opt_player| if (opt_player.*) |*player| if (player.health > 0) {
        player.update();
    };

    checkPlayerPositions(self);
}

fn fixedUpdate(self: *@This()) void {
    var iterator = self.opt_players.iterator();

    while (iterator.next()) |opt_player| if (opt_player.value.*) |*player| if (player.health > 0) {
        player.fixedUpdate();

        if (player.flash_request) |direction| {
            player.flash_request = null;

            const current_pos = b2.b2Body_GetPosition(player.body_id);
            const direction_vector = cons.DIRECTIONS[@intFromEnum(direction)];
            const dst_phys_pos = b2.b2Vec2{
                .x = current_pos.x + @as(f32, @floatFromInt(direction_vector.x * 2 * cons.PHYSICS_UNIT)),
                .y = current_pos.y + @as(f32, @floatFromInt(direction_vector.y * 2 * cons.PHYSICS_UNIT)),
            };
            const grid_pos = b2.b2Vec2{
                .x = @round(dst_phys_pos.x / cons.PHYSICS_UNIT),
                .y = @round(dst_phys_pos.y / cons.PHYSICS_UNIT),
            };

            if (grid_pos.x >= 0 and grid_pos.x < cons.GRID_SIZE.x and grid_pos.y >= 0 and grid_pos.y < cons.GRID_SIZE.y) {
                const dest_cell = self.cell_grid[@intFromFloat(grid_pos.y)][@intFromFloat(grid_pos.x)];
                if (dest_cell.tag != .wall and dest_cell.tag != .death_wall and dest_cell.tag != .barrel) {
                    b2.b2Body_SetTransform(player.body_id, .{ .x = grid_pos.x * cons.PHYSICS_UNIT, .y = grid_pos.y * cons.PHYSICS_UNIT }, .{ .c = 1, .s = 0 });
                    player.flash_timer = cons.FLASH_COOLDOWN;
                }
            }
        }

        if (player.actions.place_dynamite.cached_input) {
            player.actions.place_dynamite.cached_input = false;
            if (player.dynamite_count > 0) {
                const position = b2.b2Body_GetPosition(player.body_id);
                const grid_pos = types.Vec2(usize){
                    .x = @intFromFloat(@round(position.x / cons.PHYSICS_UNIT)),
                    .y = @intFromFloat(@round(position.y / cons.PHYSICS_UNIT)),
                };
                const cell = &self.cell_grid[grid_pos.y][grid_pos.x];
                if (cell.tag != .dynamite_1 and cell.tag != .dynamite_2) {
                    cell.* = .initDynamite(opt_player.key, player.explosion_radius);
                    player.dynamite_count -= 1;
                }
            }
        }
    };

    decayExplosions(self);
    updateDynamitesAndExplosions(self);
    b2.b2World_Step(self.world_id, cons.PHYSICS_TIMESTEP, cons.PHYSICS_SUBSTEP_COUNT);
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.gray);

    self.drawBackground();

    const alpha = self.accumulator / cons.PHYSICS_TIMESTEP;

    for (&self.opt_players.values) |*opt_player| if (opt_player.*) |*player| if (player.health > 0) {
        player.draw(alpha, self.cell_size.*);
    };

    drawGui(self);
}

fn drawGui(self: *@This()) void {
    var alive_count: u32 = 0;
    var winner: ?*const Player = null;
    var winner_team: ?types.Team = null;

    var check_iterator = self.opt_players.iterator();
    while (check_iterator.next()) |opt_player| if (opt_player.value.*) |*p| {
        if (p.health > 0) {
            alive_count += 1;
            winner = p;
            winner_team = opt_player.key;
        }
    };

    if (alive_count == 1) if (winner) |the_winner| {
        const team = winner_team.?;
        const screen_width = rl.getScreenWidth();
        const screen_height = rl.getScreenHeight();

        rl.drawRectangle(0, 0, screen_width, screen_height, rl.fade(.black, 0.75));

        var win_text_buf: [128]u8 = undefined;
        const win_text = std.fmt.bufPrintZ(&win_text_buf, "Player {s} wins!\nScore: {d}", .{
            @tagName(team),
            the_winner.score,
        }) catch "Error";

        const font_size: i32 = 60;
        const text_size = rl.measureTextEx(rl.getFontDefault() catch @panic("Failed to load default font!"), win_text, @as(f32, @floatFromInt(font_size)), 1);

        const text_pos_x = @as(f32, @floatFromInt(screen_width)) / 2.0 - text_size.x / 2.0;
        const text_pos_y = @as(f32, @floatFromInt(screen_height)) / 2.0 - text_size.y / 2.0;

        rl.drawText(win_text, @intFromFloat(text_pos_x), @intFromFloat(text_pos_y), font_size, .white);
        return;
    };

    const cell_size = self.cell_size.*;
    const gui_pixel_width = cons.GUI_SIZE * cell_size;
    const padding = gui_pixel_width / 20.0;
    const window_height = cell_size * cons.GRID_SIZE.y;
    const card_height = window_height / 4.0;

    const player_gui_size = types.Vec2(i32){
        .x = @intFromFloat(gui_pixel_width - padding * 2.0),
        .y = @intFromFloat(card_height - padding * 2.0),
    };

    rl.drawRectangle(0, 0, @intFromFloat(gui_pixel_width), @intFromFloat(window_height), .gray);

    const esc_text = "Press ESC to exit";
    const esc_font_size: i32 = @as(i32, @intFromFloat(@max(10.0, cell_size * 0.4)));
    const esc_text_width = rl.measureText(esc_text, esc_font_size);
    const esc_pos_x = @as(i32, @intFromFloat(gui_pixel_width / 2.0)) - @divTrunc(esc_text_width, 2);
    const esc_pos_y = @as(i32, @intFromFloat(window_height - padding - @as(f32, @floatFromInt(esc_font_size))));
    rl.drawText(esc_text, esc_pos_x, esc_pos_y, esc_font_size, .light_gray);

    var iterator = self.opt_players.iterator();
    while (iterator.next()) |opt_player| if (opt_player.value.*) |*player| {
        const team = opt_player.key;

        const card_pos = types.Vec2(i32){
            .x = @intFromFloat(padding),
            .y = @intFromFloat(padding + (card_height * @as(f32, @floatFromInt(iterator.index - 1)))),
        };

        const card_bg_color = if (player.health > 0) self.data.team_colors.get(team) else rl.Color.dark_gray;

        funcs.drawRectangleWithOutline(
            .{ .x = @floatFromInt(card_pos.x), .y = @floatFromInt(card_pos.y) },
            .{ .x = @floatFromInt(player_gui_size.x), .y = @floatFromInt(player_gui_size.y) },
            card_bg_color,
            cell_size / 20.0,
            .black,
        );

        const player_texture = self.team_textures.get(team).player_textures.down[0];
        const icon_size = @as(f32, @floatFromInt(player_gui_size.y)) * 0.5;
        const icon_dest_rect = rl.Rectangle{
            .x = @as(f32, @floatFromInt(card_pos.x)) + padding,
            .y = @as(f32, @floatFromInt(card_pos.y)) + padding,
            .width = icon_size,
            .height = icon_size,
        };
        rl.drawCircleV(.{ .x = icon_dest_rect.x + icon_size / 2.0, .y = icon_dest_rect.y + icon_size / 2.0 }, icon_size / 2.0 + 2.0, .white);
        rl.drawTexturePro(player_texture, .{ .x = 0, .y = 0, .width = @floatFromInt(player_texture.width), .height = @floatFromInt(player_texture.height) }, icon_dest_rect, .{ .x = 0, .y = 0 }, 0.0, .white);

        const text_area_x = @as(i32, @intFromFloat(icon_dest_rect.x + icon_dest_rect.width + padding));
        const text_area_width = card_pos.x + player_gui_size.x - @as(i32, @intFromFloat(padding)) - text_area_x;

        const name = @tagName(opt_player.key);
        var name_font_size = @as(i32, @intFromFloat(@max(12.0, cell_size * 0.5)));
        while (rl.measureText(name, name_font_size) > text_area_width and name_font_size > 8) {
            name_font_size -= 1;
        }
        const name_pos_y = @as(i32, @intFromFloat(icon_dest_rect.y));
        rl.drawText(name, text_area_x, name_pos_y, name_font_size, .black);

        var score_buf: [32]u8 = undefined;
        const score_text = std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{player.score}) catch "Score Error";
        const score_font_size = @as(i32, @intFromFloat(@max(10.0, cell_size * 0.4)));
        const score_pos_y = name_pos_y + name_font_size + @as(i32, @intFromFloat(padding * 0.5));
        rl.drawText(score_text, text_area_x, score_pos_y, score_font_size, .light_gray);

        const stats_area_y = icon_dest_rect.y + icon_dest_rect.height + padding / 2;
        const stats_available_width = @as(f32, @floatFromInt(player_gui_size.x));

        const hearth_texture = if (player.invincibility_timer > 0) self.textures.get(.invincible_hearth) else self.textures.get(.hearth);
        const heart_icon_size = cell_size * 0.4;
        const heart_spacing = heart_icon_size * 0.15;
        const num_heart_spaces = @max(0, @as(i32, @intCast(player.health)) - 1);
        const total_hearts_width = @as(f32, @floatFromInt(player.health)) * heart_icon_size + @as(f32, @floatFromInt(num_heart_spaces)) * heart_spacing;
        const hearts_start_x = @as(f32, @floatFromInt(card_pos.x)) + (stats_available_width - total_hearts_width) / 2.0;

        for (0..player.health) |j| {
            const heart_pos = rl.Vector2{
                .x = hearts_start_x + (@as(f32, @floatFromInt(j)) * (heart_icon_size + heart_spacing)),
                .y = stats_area_y,
            };
            rl.drawCircleV(.{ .x = heart_pos.x + heart_icon_size / 2.0, .y = heart_pos.y + heart_icon_size / 2.0 }, heart_icon_size / 2.0 + 1.0, .white);
            rl.drawTextureEx(hearth_texture, heart_pos, 0.0, heart_icon_size / @as(f32, @floatFromInt(hearth_texture.width)), .white);
        }

        const dynamite_texture = self.team_textures.get(team).dynamite_textures[0];
        const dynamites_y = stats_area_y + heart_icon_size + padding * 0.5;
        const dynamite_icon_size = cell_size * 0.35;
        const dynamite_spacing = dynamite_icon_size * 0.15;
        const num_dynamite_spaces = @max(0, @as(i32, @intCast(player.dynamite_count)) - 1);
        const total_dynamites_width = @as(f32, @floatFromInt(player.dynamite_count)) * dynamite_icon_size + @as(f32, @floatFromInt(num_dynamite_spaces)) * dynamite_spacing;
        const dynamites_start_x = @as(f32, @floatFromInt(card_pos.x)) + (stats_available_width - total_dynamites_width) / 2.0;

        for (0..player.dynamite_count) |j| {
            const dynamite_pos = rl.Vector2{
                .x = dynamites_start_x + (@as(f32, @floatFromInt(j)) * (dynamite_icon_size + dynamite_spacing)),
                .y = dynamites_y,
            };
            rl.drawCircleV(.{ .x = dynamite_pos.x + dynamite_icon_size / 2.0, .y = dynamite_pos.y + dynamite_icon_size / 2.0 }, dynamite_icon_size / 2.0 + 1.0, .white);
            rl.drawTextureEx(dynamite_texture, dynamite_pos, 0.0, dynamite_icon_size / @as(f32, @floatFromInt(dynamite_texture.width)), .white);
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

                if (!(@min(x, max_x) < 4 and @min(y, max_y) < 4 and @min(x, max_x) + @min(y, max_y) < 5) and (random.boolean() or random.boolean())) {
                    cell.* = .initBarrel(@intCast(x), @intCast(y), world_id);
                }
            }
        }
    }

    return cell_grid;
}

fn createTeamTextures(team_colors: std.enums.EnumArray(types.Team, rl.Color), textures: std.enums.EnumArray(types.Texture, rl.Texture2D)) std.enums.EnumArray(types.Team, types.TeamTextures) {
    var team_textures = std.enums.EnumArray(types.Team, types.TeamTextures).initUndefined();
    const shader = rl.loadShader(null, "assets/shaders/mask.fs") catch @panic("Failed to load shader!");
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
    const cell_size = self.cell_size.*;
    const ground_texture = self.textures.get(.ground);

    rl.setTextureWrap(ground_texture, rl.TextureWrap.repeat);

    const dst = rl.Rectangle{
        .x = cons.GUI_SIZE * cell_size,
        .y = 0.0,
        .width = cons.GRID_SIZE.x * cell_size,
        .height = cons.GRID_SIZE.y * cell_size,
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
                    funcs.drawGridTexture(self.textures.get(active_tag), .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, cell_size);
                },
                .explosion_1, .explosion_2 => {
                    const texture = self.team_textures.get(cell.variant.explosion_1.team).explosion_textures[@intFromBool(cell.variant.explosion_1.variant == .crossed)];

                    if (cell.variant.explosion_1.variant == .vertical) {
                        const pos = funcs.physPosToScreenPos(.{ .x = @floatFromInt(x * cons.PHYSICS_UNIT), .y = @floatFromInt(y * cons.PHYSICS_UNIT) }, cell_size);

                        funcs.drawCenteredTexture(texture, pos, 90, cell_size, false);
                    } else {
                        funcs.drawGridTexture(texture, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, cell_size);
                    }
                },
                .dynamite_1, .dynamite_2 => {
                    const texture = self.team_textures.get(cell.variant.dynamite_1.team).dynamite_textures[@intFromBool(active_tag == .dynamite_2)];

                    funcs.drawGridTexture(texture, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, cell_size);
                },
                .upgrade_dynamite, .upgrade_heal, .upgrade_radius, .upgrade_speed, .upgrade_teleport => {
                    const texture = self.textures.get(active_tag);

                    funcs.drawGridTexture(texture, .{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, cell_size);
                },
                else => unreachable,
            }
        }
    }
}

fn checkPlayerPositions(self: *@This()) void {
    var iterator = self.opt_players.iterator();

    while (iterator.next()) |opt_player| if (opt_player.value.*) |*player| if (player.health > 0) {
        const pos = b2.b2Body_GetPosition(player.body_id);
        const cell = &self.cell_grid[@intFromFloat(@round(pos.y / cons.PHYSICS_UNIT))][@intFromFloat(@round(pos.x / cons.PHYSICS_UNIT))];

        switch (cell.tag) {
            .ground, .dynamite_1, .dynamite_2 => {},
            .explosion_1, .explosion_2 => {
                const damaging_team = cell.variant.explosion_1.team;
                if (damaging_team != opt_player.key) {
                    if (self.opt_players.getPtr(damaging_team).*) |*damaging_player| {
                        if (player.invincibility_timer < 0) damaging_player.score += 25;
                    }
                }
                player.hurt();
            },
            .upgrade_dynamite => {
                player.score += 2;
                player.dynamite_count += 1;
                cell.* = .initGround();
            },
            .upgrade_heal => {
                player.score += 2;
                player.heal();
                cell.* = .initGround();
            },
            .upgrade_radius => {
                player.score += 2;
                player.explosion_radius += 1;
                cell.* = .initGround();
            },
            .upgrade_speed => {
                player.score += 2;
                player.speed += cons.PHYSICS_UNIT;
                cell.* = .initGround();
            },
            .upgrade_teleport => {
                player.score += 2;
                player.flash_timer = 0;
                cell.* = .initGround();
            },
            else => unreachable,
        }
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
                            const grid_pos = types.Vec2(usize){
                                .x = @intCast(@as(i32, @intCast(x)) + dir.x * @as(i32, @intCast(offset))),
                                .y = @intCast(@as(i32, @intCast(y)) + dir.y * @as(i32, @intCast(offset))),
                            };

                            var cell_in_radius = &self.cell_grid[grid_pos.y][grid_pos.x];
                            const cell_in_radius_active_tag = cell_in_radius.tag;

                            switch (cell_in_radius_active_tag) {
                                .wall, .death_wall, .explosion_2 => break,
                                .ground => {
                                    cell_in_radius.* = .initExplosion(
                                        cell.variant.dynamite_1.team,
                                        O: {
                                            const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;

                                            if (cell_in_radius_active_tag == .explosion_1 and cell_in_radius.variant.explosion_1.team == cell.variant.dynamite_1.team and cell_in_radius.variant.explosion_1.variant != variant)
                                                break :O .crossed;

                                            break :O variant;
                                        },
                                        .none,
                                    );
                                },
                                .explosion_1 => {
                                    cell_in_radius.* = .initExplosion(
                                        cell.variant.dynamite_1.team,
                                        O: {
                                            const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;

                                            if (cell_in_radius_active_tag == .explosion_1 and cell_in_radius.variant.explosion_1.team == cell.variant.dynamite_1.team and cell_in_radius.variant.explosion_1.variant != variant)
                                                break :O .crossed;

                                            break :O variant;
                                        },
                                        cell_in_radius.variant.explosion_1.upgrade_underneath,
                                    );
                                },
                                .barrel => {
                                    if (self.opt_players.getPtr(cell.variant.dynamite_1.team).*) |*player| {
                                        player.score += 5;
                                    }

                                    b2.b2DestroyBody(cell_in_radius.variant.barrel.body_id);

                                    var random = self.data.prng.random();

                                    cell_in_radius.* = .initExplosion(
                                        cell.variant.dynamite_1.team,
                                        O: {
                                            const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;

                                            if (cell_in_radius_active_tag == .explosion_1 and cell_in_radius.variant.explosion_1.team == cell.variant.dynamite_1.team and cell_in_radius.variant.explosion_1.variant != variant)
                                                break :O .crossed;

                                            break :O variant;
                                        },
                                        if (random.boolean()) random.enumValue(types.UpgradeUnderneath) else .none,
                                    );

                                    break :D;
                                },
                                .dynamite_1, .dynamite_2 => {
                                    cell_in_radius.variant.dynamite_1.timer = 0;

                                    break;
                                },
                                .upgrade_dynamite, .upgrade_heal, .upgrade_radius, .upgrade_speed, .upgrade_teleport => {
                                    cell_in_radius.* = .initExplosion(
                                        cell.variant.dynamite_1.team,
                                        O: {
                                            const variant: types.ExplosionVariant = if (i < 2) .horizontal else .vertical;

                                            if (cell_in_radius_active_tag == .explosion_1 and cell_in_radius.variant.explosion_1.team == cell.variant.dynamite_1.team and cell_in_radius.variant.explosion_1.variant != variant)
                                                break :O .crossed;

                                            break :O variant;
                                        },
                                        @enumFromInt(@intFromEnum(cell_in_radius_active_tag) - @intFromEnum(types.Texture.upgrade_dynamite)),
                                    );
                                },
                                else => unreachable,
                            }
                        }
                    }

                    if (self.opt_players.getPtr(cell.variant.dynamite_1.team).*) |*player| player.dynamite_count += 1;

                    cell.* = .initExplosion(cell.variant.dynamite_1.team, .crossed, .none);
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

                if (cell.variant.explosion_1.timer < 0) {
                    if (cell.variant.explosion_1.upgrade_underneath != .none) {
                        cell.* = .initUpgrade(cell.variant.explosion_1.upgrade_underneath);
                    } else cell.* = .initGround();
                }
            }
        }
    }
}
