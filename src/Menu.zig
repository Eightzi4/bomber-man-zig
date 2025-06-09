const std = @import("std");
const rl = @import("raylib");
const rgb = @import("raygui");

const types = @import("types.zig");
const Player = @import("Player.zig");

const RebindInfo = struct {
    player_index: usize,
    action: Player.MoveDirection,
};

pub const Menu = @This();

play_game: bool = false,
exit_game: bool = false,
textures: *const std.enums.EnumArray(types.Texture, rl.Texture2D),
settings: *types.GameSettings,
show_settings_window: bool = false,
is_rebinding_key: ?RebindInfo = null,

pub fn init(textures_ptr: *const std.enums.EnumArray(types.Texture, rl.Texture2D), settings_ptr: *types.GameSettings) @This() {
    return .{
        .textures = textures_ptr,
        .settings = settings_ptr,
    };
}

pub fn update(self: *@This()) void {
    if (self.is_rebinding_key) |rebind| {
        const key_code = rl.getKeyPressed();
        if (key_code != .null) {
            self.settings.player_configs[rebind.player_index].key_bindings.set(rebind.action, key_code);
            self.is_rebinding_key = null;
        }
    }
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();

    self.drawBackground();

    if (self.show_settings_window) {
        rgb.guiLock();
    }

    const screen_w = @as(f32, @floatFromInt(rl.getScreenWidth()));
    const screen_h = @as(f32, @floatFromInt(rl.getScreenHeight()));
    const btn_w: f32 = 250;
    const btn_h: f32 = 50;
    const btn_x = (screen_w - btn_w) / 2;

    if (rgb.guiButton(.{ .x = btn_x, .y = screen_h * 0.3, .width = btn_w, .height = btn_h }, "Play") != 0) {
        self.play_game = true;
    }
    if (rgb.guiButton(.{ .x = btn_x, .y = screen_h * 0.3 + 70, .width = btn_w, .height = btn_h }, "Settings") != 0) {
        self.show_settings_window = true;
    }
    if (rgb.guiButton(.{ .x = btn_x, .y = screen_h * 0.3 + 140, .width = btn_w, .height = btn_h }, "Exit") != 0) {
        self.exit_game = true;
    }

    rgb.guiUnlock();

    if (self.show_settings_window) {
        self.drawSettingsWindow();
    }
}

fn drawBackground(self: *@This()) void {
    const ground = self.textures.get(.ground);
    rl.setTextureWrap(ground, .repeat);
    const w = @as(f32, @floatFromInt(rl.getScreenWidth()));
    const h = @as(f32, @floatFromInt(rl.getScreenHeight()));
    rl.drawTexturePro(
        ground,
        .{ .x = 0, .y = 0, .width = w, .height = h },
        .{ .x = 0, .y = 0, .width = w, .height = h },
        .{ .x = 0, .y = 0 },
        0,
        .white,
    );
}

fn drawSettingsWindow(self: *@This()) void {
    const screen_w = @as(f32, @floatFromInt(rl.getScreenWidth()));
    const screen_h = @as(f32, @floatFromInt(rl.getScreenHeight()));

    rl.drawRectangle(0, 0, @intFromFloat(screen_w), @intFromFloat(screen_h), rl.fade(.black, 0.75));

    const win_w: f32 = 600;
    const win_h: f32 = 500;
    if (rgb.guiWindowBox(.{ .x = (screen_w - win_w) / 2, .y = (screen_h - win_h) / 2, .width = win_w, .height = win_h }, "Settings") != 0) {
        self.show_settings_window = false;
        self.is_rebinding_key = null;
    }

    const start_x = (screen_w - win_w) / 2;
    const start_y = (screen_h - win_h) / 2;
    var y_offset: f32 = 40;

    _ = rgb.guiLabel(.{ .x = start_x + 20, .y = start_y + y_offset, .width = 100, .height = 25 }, "Player Count:");
    _ = rgb.guiSpinner(.{ .x = start_x + 120, .y = start_y + y_offset, .width = 120, .height = 25 }, "", &self.settings.player_count, 2, 4, false);
    y_offset += 40;

    for (self.settings.player_configs[0..@intCast(self.settings.player_count)], 0..) |*p_config, i| {
        var p_name_buf: [16]u8 = undefined;
        const p_name = std.fmt.bufPrintZ(&p_name_buf, "Player {d}", .{i + 1}) catch "oops";

        const group_x = start_x + 20;
        _ = rgb.guiGroupBox(.{ .x = group_x, .y = start_y + y_offset, .width = win_w - 40, .height = 140 }, p_name);

        _ = rgb.guiLabel(.{ .x = group_x + 20, .y = start_y + y_offset + 30, .width = 100, .height = 25 }, "Team Color:");
        _ = rgb.guiColorPicker(.{ .x = group_x + 120, .y = start_y + y_offset + 20, .width = 100, .height = 100 }, "", &p_config.team_color);

        const keybind_x = group_x + 250;
        var keybind_y_offset: f32 = 30;
        var movement_iterator = p_config.key_bindings.iterator();
        while (movement_iterator.next()) |action| {
            // ... code to draw the action label ...

            // --- THE FINAL, CORRECTED AND SAFE LOGIC ---
            const button_text: [:0]const u8 = button_text_logic: {
                if (self.is_rebinding_key) |rebind| {
                    if (rebind.player_index == i and rebind.action == action.key) {
                        break :button_text_logic "...";
                    }
                }
                // Now this check is safe, because action.value.* is guaranteed
                // to be a valid MoveAction struct.
                if (action.value.* == .null) {
                    break :button_text_logic "Not Bound";
                } else {
                    break :button_text_logic @tagName(action.value.*);
                }
            };

            if (rgb.guiButton(.{ .x = keybind_x + 60, .y = start_y + y_offset + keybind_y_offset, .width = 150, .height = 25 }, button_text) != 0) {
                self.is_rebinding_key = .{ .player_index = i, .action = action.key };
            }

            keybind_y_offset += 30;
        }
        y_offset += 160;
    }
}
