const std = @import("std");
const rl = @import("raylib");
const b2 = @cImport({
    @cInclude("box2d/box2d.h");
});

const types = @import("types.zig");
const cons = @import("constants.zig");

pub fn isPointInRect(point: types.Vec2, rect_pos: types.Vec2, rect_size: types.Vec2) bool {
    return point.x >= rect_pos.x and point.x < rect_pos.x + rect_size.x and point.y >= rect_pos.y and point.y < rect_pos.y + rect_size.y;
}

pub fn screenPosToPhysPos(screen_pos: b2.b2Vec2, cell_size: f32) b2.b2Vec2 {
    return .{
        .x = (screen_pos.x - cell_size / 2 - cell_size * cons.GUI_SIZE) / cell_size * cons.PHYSICS_UNIT,
        .y = (screen_pos.y - cell_size / 2) / cell_size * cons.PHYSICS_UNIT,
    };
}

pub fn physPosToScreenPos(phys_pos: b2.b2Vec2, cell_size: f32) b2.b2Vec2 {
    return .{
        .x = phys_pos.x / cons.PHYSICS_UNIT * cell_size + cell_size / 2 + cell_size * cons.GUI_SIZE,
        .y = phys_pos.y / cons.PHYSICS_UNIT * cell_size + cell_size / 2,
    };
}

pub fn drawRectangleWithOutline(pos: b2.b2Vec2, size: b2.b2Vec2, color: rl.Color, outline_thickness: f32, outline_color: rl.Color) void {
    rl.drawRectangle(@intFromFloat(pos.x), @intFromFloat(pos.y), @intFromFloat(size.x), @intFromFloat(size.y), color);
    rl.drawRectangleLinesEx(
        .{ .x = pos.x, .y = pos.y, .width = size.x, .height = size.y },
        outline_thickness,
        outline_color,
    );
}

pub fn drawGridTexture(texture: rl.Texture2D, pos: b2.b2Vec2, cell_size: f32) void {
    drawTexture(texture, .{ .x = cons.GUI_SIZE * cell_size + cell_size * pos.x + cell_size / 2, .y = cell_size * pos.y + cell_size / 2 }, 0, cell_size);
}

pub fn drawCenteredTexture(texture: rl.Texture2D, pos: b2.b2Vec2, rot: f32, cell_size: f32) void {
    drawTexture(texture, pos, rot, cell_size);
}

fn drawTexture(texture: rl.Texture2D, pos: b2.b2Vec2, rot: f32, cell_size: f32) void {
    const scale = cell_size / @as(f32, @floatFromInt(texture.width));
    const src = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(texture.width),
        .height = @floatFromInt(texture.height),
    };
    const dest = rl.Rectangle{
        .x = pos.x,
        .y = pos.y,
        .width = @as(f32, @floatFromInt(texture.width)) * scale,
        .height = @as(f32, @floatFromInt(texture.height)) * scale,
    };
    const origin = rl.Vector2{
        .x = @as(f32, @floatFromInt(texture.width)) * scale / 2,
        .y = @as(f32, @floatFromInt(texture.height)) * scale / 2,
    };

    rl.drawTexturePro(texture, src, dest, origin, rot, .white);
}

pub fn createCollider(x: usize, y: usize, world_id: b2.b2WorldId) b2.b2BodyId {
    var body_def = b2.b2DefaultBodyDef();
    body_def.position = .{
        .x = @floatFromInt(cons.PHYSICS_UNIT * x),
        .y = @floatFromInt(cons.PHYSICS_UNIT * y),
    };

    const body_id = b2.b2CreateBody(world_id, &body_def);

    _ = b2.b2CreatePolygonShape(
        body_id,
        &b2.b2DefaultShapeDef(),
        &b2.b2MakeBox(@as(f32, @floatFromInt(cons.PHYSICS_UNIT)) / 2, @as(f32, @floatFromInt(cons.PHYSICS_UNIT)) / 2),
    );

    return body_id;
}
