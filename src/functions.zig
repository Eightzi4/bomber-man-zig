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
