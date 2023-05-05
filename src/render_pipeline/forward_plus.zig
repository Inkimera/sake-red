const std = @import("std");
const raylib = @import("raylib.zig");

const g_buffer = @import("buffer/g_buffer.zig");
const e_buffer = @import("buffer/e_buffer.zig");
const p_buffer = @import("buffer/p_buffer.zig");
const render_pass = @import("render_pass.zig");
const model = @import("model.zig");

const MAX_PASSES: usize = 12;

pub const ForwardPlus = struct {
    _gbuf: g_buffer.GBuffer,
    _ebuf: e_buffer.EBuffer,
    _pbuf: p_buffer.PBuffer,
    _pass_count: usize,
    _passes: [MAX_PASSES]?render_pass.RenderPass,

    pub fn init() ForwardPlus {
        return ForwardPlus{
            ._gbuf = g_buffer.GBuffer.init(),
            ._ebuf = e_buffer.EBuffer.init(),
            ._pbuf = p_buffer.PBuffer.init(),
            ._pass_count = 0,
            ._passes = std.mem.zeroes([MAX_PASSES]?render_pass.RenderPass),
        };
    }

    pub fn resize(self: *ForwardPlus) void {
        if (self._gbuf.color.width != raylib.GetScreenWidth() or self._gbuf.color.height != raylib.GetScreenHeight()) {
            self._gbuf.deinit();
            self._gbuf = g_buffer.GBuffer.init();
            self._ebuf.deinit();
            self._ebuf = e_buffer.EBuffer.init();
            self._pbuf.deinit();
            self._pbuf = p_buffer.PBuffer.init();
        }
    }

    pub fn addPass(self: *ForwardPlus, pass: render_pass.RenderPass) void {
        self._passes[self._pass_count] = pass;
        self._pass_count += 1;
    }

    pub fn render(self: *const ForwardPlus, camera: raylib.Camera, models: []*model.Model) void {
        for (self._passes) |pass| {
            if (pass) |p| {
                p.runPass(&self._gbuf, &self._ebuf, &self._pbuf, &camera, models);
            } else {
                break;
            }
        }
    }
};
