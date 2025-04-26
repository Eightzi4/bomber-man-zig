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
    texture: types.Texture = .ground,
    body_id: ?b2.b2BodyId = null,
};

cell_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]Cell = [_][cons.GRID_SIZE.x]Cell{[_]Cell{Cell{}} ** cons.GRID_SIZE.x} ** cons.GRID_SIZE.y,
textures: std.enums.EnumArray(types.Texture, rl.Texture2D) = .initUndefined(),
world_id: b2.b2WorldId,
optional_players: [4]?Player = .{null} ** 4,

pub fn init(allocator: std.mem.Allocator, random: std.Random) @This() {
    var self = @This(){
        .world_id = b2.b2CreateWorld(&b2.b2DefaultWorldDef()),
    };

    self.generateTextureGrid(random);
    self.loadTextures(allocator);

    return self;
}

pub fn deinit(self: *@This()) void {
    self.unloadTextures();
}

pub fn update(self: *@This()) void {
    b2.b2World_Step(self.world_id, rl.getFrameTime(), 4);

    for (&self.optional_players) |*player_slot| if (player_slot.*) |*player| player.update();

    handleExplosions(self);
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    self.drawBackground();
    for (&self.optional_players) |*player_slot| if (player_slot.*) |*player| player.draw(self.textures);
    funcs.drawGui();
}

fn generateTextureGrid(self: *@This(), random: std.Random) void {
    const createCollider = struct {
        fn createCollider(x: usize, y: usize, world_id: b2.b2WorldId) b2.b2BodyId {
            var body_def = b2.b2DefaultBodyDef();
            body_def.position = .{
                .x = @floatFromInt(cons.GUI_SIZE + cons.CELL_SIZE * x + cons.CELL_SIZE / 2),
                .y = @floatFromInt(cons.CELL_SIZE * y + cons.CELL_SIZE / 2),
            };

            const body_id = b2.b2CreateBody(world_id, &body_def);

            _ = b2.b2CreatePolygonShape(
                body_id,
                &b2.b2DefaultShapeDef(),
                &b2.b2MakeBox(cons.CELL_SIZE / 2, cons.CELL_SIZE / 2),
            );

            return body_id;
        }
    }.createCollider;

    for (&self.cell_grid, 0..) |*row, y| {
        for (row, 0..) |*cell, x| {
            if (y % (cons.GRID_SIZE.y - 1) == 0 or x % (cons.GRID_SIZE.x - 1) == 0 or x % 2 == 0 and y % 2 == 0) {
                cell.texture = .wall;
                cell.body_id = createCollider(x, y, self.world_id);
            } else {
                const max_y = cons.GRID_SIZE.y - y - 1;
                const max_x = cons.GRID_SIZE.x - x - 1;

                if (!(@min(x, max_x) < 4 and @min(y, max_y) < 4 and @min(x, max_x) + @min(y, max_y) < 5) and
                    (random.boolean() or random.boolean()))
                {
                    cell.texture = .barrel;
                    cell.body_id = createCollider(x, y, self.world_id);
                }
            }
        }
    }
}

fn loadTextures(self: *@This(), allocator: std.mem.Allocator) void {
    const asset_folder_path = std.fs.cwd().realpathAlloc(allocator, "") catch unreachable;
    defer allocator.free(asset_folder_path);

    for (&self.textures.values, 0..) |*texture, i| {
        const texture_path = std.mem.concatWithSentinel(
            allocator,
            u8,
            &.{ asset_folder_path, "\\assets\\images\\", cons.TEXTURE_ASSET_NAMES[i] },
            0,
        ) catch unreachable;
        defer allocator.free(texture_path);

        var image = rl.loadImage(texture_path) catch unreachable;

        image.resize(cons.CELL_SIZE, cons.CELL_SIZE);

        texture.* = rl.loadTextureFromImage(image) catch unreachable;
    }
}

fn unloadTextures(self: *@This()) void {
    for (self.textures.values) |texture| rl.unloadTexture(texture);
}

fn drawBackground(self: *@This()) void {
    for (0..cons.GRID_SIZE.y) |y| {
        for (0..cons.GRID_SIZE.x) |x| {
            const pos = types.Vec2{
                .x = cons.GUI_SIZE + cons.CELL_SIZE * @as(i32, @intCast(x)),
                .y = cons.CELL_SIZE * @as(i32, @intCast(y)),
            };

            rl.drawTexture(self.textures.get(self.cell_grid[y][x].texture), pos.x, pos.y, rl.Color.white);
        }
    }
}

//TODO: Refactor
pub fn handleExplosions(self: *@This()) void {
    for (&self.optional_players) |*optional_player| if (optional_player.*) |*player| {
        for (&player.optional_dynamites) |*optional_dynamite| if (optional_dynamite.*) |*dynamite| {
            if (dynamite.timer > -cons.EXPLOSION_DURATION and dynamite.timer < 0) {
                //TODO: hurt players inside explosion
            } else {
                const directions = [4]types.Vec2{
                    .{ .x = -1, .y = 0 },
                    .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 },
                    .{ .x = 0, .y = 1 },
                };

                const grid_position = funcs.gridPositionFromPixelPosition(dynamite.position);

                if (dynamite.timer == 0) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture = if (dynamite.team_color == .blue) .blue_crossed_explosion else .red_crossed_explosion;

                    for (directions, 0..) |dir, i| {
                        for (1..dynamite.radius) |offset| {
                            const cell_x = @as(usize, @intCast(grid_position.x + dir.x * @as(i32, @intCast(offset))));
                            const cell_y = @as(usize, @intCast(grid_position.y + dir.y * @as(i32, @intCast(offset))));

                            var cell = &self.cell_grid[cell_y][cell_x];
                            if (cell.texture != .wall and cell.texture != .blue_crossed_explosion and cell.texture != .red_crossed_explosion) {
                                if (dynamite.team_color == .blue) {
                                    if (i < 2) {
                                        if (cell.texture == .blue_vertical_explosion) {
                                            cell.texture = .blue_crossed_explosion;
                                        } else cell.texture = .blue_horizontal_explosion;
                                    } else {
                                        if (cell.texture == .blue_horizontal_explosion) {
                                            cell.texture = .blue_crossed_explosion;
                                        } else cell.texture = .blue_vertical_explosion;
                                    }
                                } else {
                                    if (i < 2) {
                                        if (cell.texture == .red_vertical_explosion) {
                                            cell.texture = .red_crossed_explosion;
                                        } else cell.texture = .red_horizontal_explosion;
                                    } else {
                                        if (cell.texture == .red_horizontal_explosion) {
                                            cell.texture = .red_crossed_explosion;
                                        } else cell.texture = .red_vertical_explosion;
                                    }
                                }

                                if (cell.body_id) |body_id| {
                                    b2.b2DestroyBody(body_id);
                                    cell.body_id = null;

                                    break;
                                } else {
                                    for (&self.optional_players) |*optional_player_2| if (optional_player_2.*) |*player_2| {
                                        for (&player_2.optional_dynamites) |*optional_dynamite_2| if (optional_dynamite_2.*) |*dynamite_2| {
                                            const grid_position2 = funcs.gridPositionFromPixelPosition(dynamite_2.position);

                                            if (grid_position2.x == cell_x and grid_position2.y == cell_y) dynamite_2.timer = 0;
                                            //TODO: should break here when placement of multiple dynamites in one cell is impossible
                                        };
                                    };
                                }
                            } else break;
                        }
                    }
                } else if (dynamite.timer == -cons.EXPLOSION_DURATION) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture = .ground;

                    for (directions) |dir| {
                        for (1..dynamite.radius) |offset| {
                            const cell_x = @as(usize, @intCast(grid_position.x + dir.x * @as(i32, @intCast(offset))));
                            const cell_y = @as(usize, @intCast(grid_position.y + dir.y * @as(i32, @intCast(offset))));

                            var cell = &self.cell_grid[cell_y][cell_x];
                            if (cell.texture != .wall) {
                                if (cell.texture == .blue_horizontal_explosion or cell.texture == .blue_vertical_explosion or cell.texture == .blue_crossed_explosion or cell.texture == .red_horizontal_explosion or cell.texture == .red_vertical_explosion or cell.texture == .red_crossed_explosion) cell.texture = .ground;
                            } else break;
                        }
                    }

                    optional_dynamite.* = null;
                }
            }
        };
    };
}
