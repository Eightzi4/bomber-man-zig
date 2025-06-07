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

pub fn gridPositionFromPixelPosition(pixel_position: b2.b2Vec2) types.Vec2 {
    return .{
        .x = @divExact(@as(i32, @intFromFloat(pixel_position.x - cons.CELL_SIZE / 2 - cons.GUI_SIZE)), cons.CELL_SIZE),
        .y = @divExact(@as(i32, @intFromFloat(pixel_position.y - cons.CELL_SIZE / 2)), cons.CELL_SIZE),
    };
}

pub fn gridPositionFromPixelPosition2(pixel_position: b2.b2Vec2) types.Vec2 {
    return .{
        .x = @divTrunc(@as(i32, @intFromFloat(pixel_position.x - cons.CELL_SIZE / 2 - cons.GUI_SIZE)), cons.CELL_SIZE),
        .y = @divTrunc(@as(i32, @intFromFloat(pixel_position.y - cons.CELL_SIZE / 2)), cons.CELL_SIZE),
    };
}

pub fn drawRectangleWithOutline(pos: types.Vec2, size: types.Vec2, color: rl.Color, outline_thickness: f32, outline_color: rl.Color) void {
    rl.drawRectangle(pos.x, pos.y, size.x, size.y, color);
    rl.drawRectangleLinesEx(
        .{ .x = @floatFromInt(pos.x), .y = @floatFromInt(pos.y), .width = @floatFromInt(size.x), .height = @floatFromInt(size.y) },
        outline_thickness,
        outline_color,
    );
}

pub fn drawGridTexture(texture: rl.Texture2D, pos: types.Vec2) void {
    drawTexture(texture, .{ .x = @floatFromInt(cons.GUI_SIZE + cons.CELL_SIZE * pos.x + cons.CELL_SIZE / 2), .y = @floatFromInt(cons.CELL_SIZE * pos.y + cons.CELL_SIZE / 2) }, 0);
}

pub fn drawCenteredTexture(texture: rl.Texture2D, pos: b2.b2Vec2, rot: f32) void {
    drawTexture(texture, pos, rot);
}

fn drawTexture(texture: rl.Texture2D, pos: b2.b2Vec2, rot: f32) void {
    const scale = cons.CELL_SIZE / @as(f32, @floatFromInt(texture.width));
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

fn generateMaskedTextures(original: rl.Texture2D) [3]rl.Texture2D {
    const colors = [3][3]f32{
        [3]f32{ 1.0, 0.0, 0.0 }, // Red
        [3]f32{ 0.0, 1.0, 0.0 }, // Green
        [3]f32{ 0.0, 0.0, 1.0 }, // Blue
    };

    var result: [3]rl.Texture2D = undefined;
    const shader = rl.loadShader(null, "mask.fs") catch @panic("Shader load failed!");

    // Preserve original texture filter
    const originalFilter = rl.TextureFilter.bilinear; // Default
    rl.setTextureFilter(original, rl.TextureFilter.point);

    for (colors, 0..) |color, i| {
        // Create render target
        const target = try rl.loadRenderTexture(original.width, original.height);

        // Draw to render texture
        rl.beginTextureMode(target);
        rl.clearBackground(.{ .r = 0, .g = 0, .b = 0, .a = 0 }); // Transparent

        rl.beginShaderMode(shader);
        rl.setShaderValue(shader, rl.getShaderLocation(shader, "color"), &color, rl.ShaderUniformDataType.vec3);
        rl.drawTexture(original, 0, 0, .white);
        rl.endShaderMode();
        rl.endTextureMode();

        // Extract texture from render target
        result[i] = rl.loadTextureFromImage(rl.loadImageFromTexture(target.texture));
        rl.unloadRenderTexture(target);
    }

    // Cleanup
    rl.setTextureFilter(original, originalFilter);
    rl.unloadShader(shader);
    return result;
}

pub fn createCollider(x: usize, y: usize, world_id_2: b2.b2WorldId) b2.b2BodyId {
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
