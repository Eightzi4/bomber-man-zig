const std = @import("std");
const rl = @import("raylib");
const rgb = @import("raygui");

const types = @import("types.zig");
const Player = @import("Player.zig");
const Data = @import("Data.zig");

const RebindInfo = struct {
    team: types.Team,
    action: Player.MoveDirection,
};

pub const Menu = @This();

play_game: bool,
exit_game: bool,
data: *Data,
show_settings_window: bool,
is_rebinding_key: ?RebindInfo,

pub fn init(data_ptr: *Data) @This() {
    return .{
        .play_game = false,
        .exit_game = false,
        .data = data_ptr,
        .show_settings_window = false,
        .is_rebinding_key = null,
    };
}

pub fn update(self: *@This()) void {
    if (self.is_rebinding_key) |rebind| {
        const key_code = rl.getKeyPressed();
        if (key_code != .null) {
            var actions = self.data.key_bindings.getPtr(rebind.team);
            actions.movement.getPtr(rebind.action).*.binded_key = key_code;
            self.is_rebinding_key = null;
        }
    }
}

pub fn draw(self: *@This()) void {
    rl.beginDrawing();
    defer rl.endDrawing();
    self.drawBackground();

    const title_text = "Playing with Fire Reborn";
    const title_font_size: i32 = 60;
    const screen_w_int = rl.getScreenWidth();
    const title_width = rl.measureText(title_text, title_font_size);
    const title_x = @divTrunc(screen_w_int - title_width, 2);
    const title_y = @as(i32, @intFromFloat(@as(f32, @floatFromInt(rl.getScreenHeight())) * 0.1));

    rl.drawText(title_text, title_x, title_y, title_font_size, .black);

    if (self.show_settings_window) {
        rgb.guiLock();
    }

    const screen_w = @as(f32, @floatFromInt(screen_w_int));
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
    const ground = self.data.textures.get(.ground);
    rl.setTextureWrap(ground, .repeat);
    const w = @as(f32, @floatFromInt(rl.getScreenWidth()));
    const h = @as(f32, @floatFromInt(rl.getScreenHeight()));
    rl.drawTexturePro(ground, .{ .x = 0, .y = 0, .width = w, .height = h }, .{ .x = 0, .y = 0, .width = w, .height = h }, .{ .x = 0, .y = 0 }, 0, .white);
}

fn drawSettingsWindow(self: *@This()) void {
    const screen_w = @as(f32, @floatFromInt(rl.getScreenWidth()));
    const screen_h = @as(f32, @floatFromInt(rl.getScreenHeight()));

    rl.drawRectangle(0, 0, @intFromFloat(screen_w), @intFromFloat(screen_h), rl.fade(.black, 0.75));

    const win_w: f32 = 600;
    const player_group_height: f32 = 160;
    const win_h: f32 = 80 + (@as(f32, @floatFromInt(self.data.player_count)) * player_group_height);

    if (rgb.guiWindowBox(.{ .x = (screen_w - win_w) / 2, .y = (screen_h - win_h) / 2, .width = win_w, .height = win_h }, "Settings") != 0) {
        self.show_settings_window = false;
        self.is_rebinding_key = null;
    }

    const start_x = (screen_w - win_w) / 2;
    const start_y = (screen_h - win_h) / 2;
    var y_offset: f32 = 40;

    _ = rgb.guiLabel(.{ .x = start_x + 20, .y = start_y + y_offset, .width = 100, .height = 25 }, "Player Count:");
    _ = rgb.guiSpinner(.{ .x = start_x + 120, .y = start_y + y_offset, .width = 120, .height = 25 }, "", &self.data.player_count, 2, 4, false);
    y_offset += 40;

    for (0..@intCast(self.data.player_count)) |i| {
        const team: types.Team = @enumFromInt(i);

        var p_name_buf: [16]u8 = undefined;
        const p_name = std.fmt.bufPrintZ(&p_name_buf, "Player {d}", .{i + 1}) catch "oops";

        const group_x = start_x + 20;
        _ = rgb.guiGroupBox(.{ .x = group_x, .y = start_y + y_offset, .width = win_w - 40, .height = player_group_height - 20 }, p_name);

        _ = rgb.guiLabel(.{ .x = group_x + 20, .y = start_y + y_offset + 30, .width = 100, .height = 25 }, "Team Color:");
        _ = rgb.guiColorPicker(.{ .x = group_x + 120, .y = start_y + y_offset + 20, .width = 100, .height = 100 }, "", self.data.team_colors.getPtr(team));

        const keybind_x = group_x + 250;
        var keybind_y_offset: f32 = 30;

        var movement_iterator = self.data.key_bindings.getPtr(team).movement.iterator();
        while (movement_iterator.next()) |action| {
            var label_buf: [16]u8 = undefined;
            const label = std.fmt.bufPrintZ(&label_buf, "{s}:", .{@tagName(action.key)}) catch "oops";
            _ = rgb.guiLabel(.{ .x = keybind_x, .y = start_y + y_offset + keybind_y_offset, .width = 50, .height = 25 }, label);

            const button_text = button_text_logic: {
                if (self.is_rebinding_key) |rebind| {
                    if (rebind.team == team and rebind.action == action.key) break :button_text_logic "...";
                }
                if (action.value.binded_key == .null) break :button_text_logic "Not Bound";

                break :button_text_logic @tagName(action.value.binded_key);
            };

            if (rgb.guiButton(.{ .x = keybind_x + 60, .y = start_y + y_offset + keybind_y_offset, .width = 150, .height = 25 }, button_text) != 0) {
                self.is_rebinding_key = .{ .team = team, .action = action.key };
            }

            keybind_y_offset += 30;
        }

        y_offset += player_group_height;
    }
}
