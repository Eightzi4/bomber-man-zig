const std = @import("std");
const rl = @import("raylib");
const constants = @import("constants.zig");

play_game: bool,
settings: bool,
exit_game: bool,
play_button: rl.Rectangle,
settings_button: rl.Rectangle,
exit_button: rl.Rectangle,
play_hovered: bool,
settings_hovered: bool,
exit_hovered: bool,

pub fn init() @This() {
    const screenWidth = constants.WINDOW_SIZE.x;

    const buttonWidth = 200;
    const buttonHeight = 50;
    const buttonSpacing = 20;

    const playButtonY = 150;
    const settingsButtonY = playButtonY + buttonHeight + buttonSpacing;
    const exitButtonY = settingsButtonY + buttonHeight + buttonSpacing;

    return .{
        .play_game = false,
        .settings = false,
        .exit_game = false,
        .play_button = .{
            .x = @as(f32, @floatFromInt(screenWidth)) / 2 - @as(f32, @floatFromInt(buttonWidth)) / 2,
            .y = @floatFromInt(playButtonY),
            .width = @floatFromInt(buttonWidth),
            .height = @floatFromInt(buttonHeight),
        },
        .settings_button = .{
            .x = @as(f32, @floatFromInt(screenWidth)) / 2 - @as(f32, @floatFromInt(buttonWidth)) / 2,
            .y = @floatFromInt(settingsButtonY),
            .width = @floatFromInt(buttonWidth),
            .height = @floatFromInt(buttonHeight),
        },
        .exit_button = .{
            .x = @as(f32, @floatFromInt(screenWidth)) / 2 - @as(f32, @floatFromInt(buttonWidth)) / 2,
            .y = @floatFromInt(exitButtonY),
            .width = @floatFromInt(buttonWidth),
            .height = @floatFromInt(buttonHeight),
        },
        .play_hovered = false,
        .settings_hovered = false,
        .exit_hovered = false,
    };
}

pub fn deinit(_: *@This()) void {}

pub fn update(self: *@This()) void {
    const mousePos = rl.getMousePosition();

    // Update hover states
    self.play_hovered = rl.checkCollisionPointRec(mousePos, self.play_button);
    self.settings_hovered = rl.checkCollisionPointRec(mousePos, self.settings_button);
    self.exit_hovered = rl.checkCollisionPointRec(mousePos, self.exit_button);

    // Handle clicks
    if (rl.isMouseButtonPressed(.left)) {
        if (self.play_hovered) {
            self.play_game = true;
        }
        if (self.settings_hovered) {
            self.settings = true;
        }
        if (self.exit_hovered) {
            self.exit_game = true;
        }
    }
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    // Draw title
    const titleText = "Playing with Fire Reborn";
    const titleFontSize = 40;
    const titleWidth = rl.measureText(titleText, titleFontSize);
    const titleX = @divTrunc(constants.WINDOW_SIZE.x - titleWidth, 2);
    rl.drawText(titleText, titleX, 50, titleFontSize, rl.Color.white);

    // Draw buttons
    self.drawButton(self.play_button, "Play", self.play_hovered);
    self.drawButton(self.settings_button, "Settings", self.settings_hovered);
    self.drawButton(self.exit_button, "Exit", self.exit_hovered);

    // Draw version text
    const versionText = "v1.0 by Eightzi4";
    const versionFontSize = 20;
    rl.drawText(
        versionText,
        10,
        constants.WINDOW_SIZE.y - 30,
        versionFontSize,
        rl.Color.white,
    );
}

fn drawButton(_: *@This(), rect: rl.Rectangle, text: [:0]const u8, hovered: bool) void {
    // Button color based on hover state
    const color = if (hovered) rl.Color.sky_blue else rl.Color.blue;
    rl.drawRectangleRec(rect, color);

    // Button text
    const fontSize = 30;
    const textWidth = rl.measureText(text, fontSize);
    const textX = @as(i32, @intFromFloat(rect.x)) + @divTrunc(@as(i32, @intFromFloat(rect.width)) - textWidth, 2);
    const textY = @as(i32, @intFromFloat(rect.y)) + 10;

    rl.drawText(text, textX, textY, fontSize, rl.Color.white);
}
