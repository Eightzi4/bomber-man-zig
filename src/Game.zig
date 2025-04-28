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
    texture: types.TextureWrapper = .ground(),
    body_id: ?b2.b2BodyId = null,
};

cell_grid: [cons.GRID_SIZE.y][cons.GRID_SIZE.x]Cell = [_][cons.GRID_SIZE.x]Cell{[_]Cell{Cell{}} ** cons.GRID_SIZE.x} ** cons.GRID_SIZE.y,
textures: std.HashMap(types.TextureWrapper, rl.Texture2D, types.TextureContext, std.hash_map.default_max_load_percentage),
world_id: b2.b2WorldId,
optional_players: [4]?Player = .{null} ** 4,

// TODO: Refactor
pub fn init(allocator: std.mem.Allocator, random: std.Random) @This() {
    var self = @This(){
        .world_id = b2.b2CreateWorld(&b2.b2DefaultWorldDef()),
        .textures = .initContext(allocator, .{}),
    };

    self.generateTextureGrid(random);
    self.loadTextures(allocator);

    return self;
}

pub fn deinit(self: *@This()) void {
    self.unloadTextures();
    self.textures.deinit();
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
                cell.texture = .wall();
                cell.body_id = createCollider(x, y, self.world_id);
            } else {
                const max_y = cons.GRID_SIZE.y - y - 1;
                const max_x = cons.GRID_SIZE.x - x - 1;

                if (!(@min(x, max_x) < 4 and @min(y, max_y) < 4 and @min(x, max_x) + @min(y, max_y) < 5) and
                    (random.boolean() or random.boolean()))
                {
                    cell.texture = .barrel();
                    cell.body_id = createCollider(x, y, self.world_id);
                }
            }
        }
    }
}

fn loadTextures(self: *@This(), allocator: std.mem.Allocator) void {
    const assets_dir = "assets/images";
    var dir = std.fs.cwd().openDir(assets_dir, .{ .iterate = true }) catch {
        @panic("Failed to open assets directory!");
    };
    defer dir.close();

    var file_iterator = dir.iterate();
    while (file_iterator.next() catch @panic("Directory iteration failed!")) |entry| {
        if (entry.kind != .file) continue;

        // TODO: Only use .png image assets
        const ext = std.fs.path.extension(entry.name);
        if (!std.mem.eql(u8, ext, ".png") and !std.mem.eql(u8, ext, ".jpg")) continue;

        const file_name = entry.name[0 .. entry.name.len - ext.len];
        var file_name_parts_iterator = std.mem.splitAny(u8, file_name, "_");

        // TODO: Refactor panic messages
        const key: types.TextureWrapper = switch (std.meta.stringToEnum(std.meta.FieldEnum(types.Texture), file_name_parts_iterator.next() orelse @panic("Asset file has no name!")).?) {
            .ground => .ground(),
            .wall => .wall(),
            .barrel => .barrel(),
            .player => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Invalid team color!")).?;
                break :D .player(team_color);
            },
            .dynamite => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Invalid team color!")).?;
                break :D .dynamite(team_color);
            },
            .explosion => D: {
                const team_color = std.meta.stringToEnum(types.TeamColor, file_name_parts_iterator.next() orelse @panic("Invalid team color!")).?;
                const variant = std.meta.stringToEnum(types.ExplosionVariant, file_name_parts_iterator.next() orelse @panic("Invalid variant!")).?;
                break :D .explosion(team_color, variant);
            },
        };

        const texture_path = std.fs.path.joinZ(allocator, &.{ assets_dir, entry.name }) catch @panic("Out of memory!");
        defer allocator.free(texture_path);

        var image = rl.loadImage(texture_path) catch @panic("Failed to load image!");
        defer rl.unloadImage(image);
        image.resize(cons.CELL_SIZE, cons.CELL_SIZE);

        const texture = rl.loadTextureFromImage(image) catch @panic("Failed to create texture!");

        self.textures.put(key, texture) catch @panic("Out of memory!");
    }
}

fn unloadTextures(self: *@This()) void {
    var iterator = self.textures.iterator();
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

// TODO: Refactor
pub fn handleExplosions(self: *@This()) void {
    for (&self.optional_players) |*optional_player| if (optional_player.*) |*player| {
        for (&player.optional_dynamites) |*optional_dynamite| if (optional_dynamite.*) |*dynamite| {
            if (dynamite.timer > -cons.EXPLOSION_DURATION and dynamite.timer < 0) {
                // TODO: hurt players inside explosion
            } else {
                const directions = [4]types.Vec2{
                    .{ .x = -1, .y = 0 },
                    .{ .x = 1, .y = 0 },
                    .{ .x = 0, .y = -1 },
                    .{ .x = 0, .y = 1 },
                };

                const grid_position = funcs.gridPositionFromPixelPosition(dynamite.position);

                if (dynamite.timer == 0) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture = .explosion(dynamite.team_color, .crossed);

                    for (directions, 0..) |dir, i| {
                        for (1..dynamite.radius) |offset| {
                            const cell_position = grid_position.add(dir.mul_scalar(@intCast(offset)));

                            var cell = &self.cell_grid[@intCast(cell_position.y)][@intCast(cell_position.x)];
                            if (cell.texture.tag != .wall and !(cell.texture.tag == .explosion and cell.texture.data.explosion.variant == .crossed)) {
                                cell.texture = .explosion(
                                    dynamite.team_color,
                                    D: {
                                        if (i < 2) {
                                            if (cell.texture.data.explosion.variant == .vertical) {
                                                break :D .crossed;
                                            }
                                            break :D .horizontal;
                                        }

                                        if (cell.texture.data.explosion.variant == .horizontal) {
                                            break :D .crossed;
                                        }
                                        break :D .vertical;
                                    },
                                );

                                if (cell.body_id) |body_id| {
                                    b2.b2DestroyBody(body_id);
                                    cell.body_id = null;

                                    break;
                                } else {
                                    for (&self.optional_players) |*optional_player_2| if (optional_player_2.*) |*player_2| {
                                        for (&player_2.optional_dynamites) |*optional_dynamite_2| if (optional_dynamite_2.*) |*dynamite_2| {
                                            if (funcs.gridPositionFromPixelPosition(dynamite_2.position).eql(cell_position)) dynamite_2.timer = 0;
                                            // TODO: should break here once placement of multiple dynamites in one cell is impossible
                                        };
                                    };
                                }
                            } else break;
                        }
                    }
                } else if (dynamite.timer == -cons.EXPLOSION_DURATION) {
                    self.cell_grid[@intCast(grid_position.y)][@intCast(grid_position.x)].texture.tag = .ground;

                    for (directions) |dir| {
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
            }
        };
    };
}
