const std = @import("std");
const raylib = @import("raylib.zig");

const s_buffer = @import("buffer/s_buffer.zig");
const g_buffer = @import("buffer/g_buffer.zig");
const e_buffer = @import("buffer/e_buffer.zig");
const p_buffer = @import("buffer/p_buffer.zig");
//const render_pass = @import("render_pass.zig");
const light = @import("../light.zig");
const model = @import("model.zig");

const MAX_PASSES: usize = 16;

pub fn ForwardPlus(comptime r: type) type {
    return struct {
        const Self = @This();

        _sbuf: s_buffer.SBuffer,
        _gbuf: g_buffer.GBuffer,
        _ebuf: e_buffer.EBuffer,
        _pbuf: p_buffer.PBuffer,
        _pass_count: usize,
        _passes: [MAX_PASSES]?r,

        pub fn init() Self {
            return Self{
                ._sbuf = s_buffer.SBuffer.init(),
                ._gbuf = g_buffer.GBuffer.init(),
                ._ebuf = e_buffer.EBuffer.init(),
                ._pbuf = p_buffer.PBuffer.init(),
                ._pass_count = 0,
                ._passes = std.mem.zeroes([MAX_PASSES]?r),
            };
        }

        pub fn resize(self: *Self) void {
            if (self._gbuf.color.width != raylib.GetScreenWidth() or self._gbuf.color.height != raylib.GetScreenHeight()) {
                self._sbuf.deinit();
                self._sbuf = s_buffer.SBuffer.init();
                self._gbuf.deinit();
                self._gbuf = g_buffer.GBuffer.init();
                self._ebuf.deinit();
                self._ebuf = e_buffer.EBuffer.init();
                self._pbuf.deinit();
                self._pbuf = p_buffer.PBuffer.init();
            }
        }

        pub fn addPass(self: *Self, pass: r) void {
            self._passes[self._pass_count] = pass;
            self._pass_count += 1;
        }

        pub fn render(self: *const Self, camera: raylib.Camera, lights: []*light.Light, models: []*model.Model) void {
            for (self._passes) |pass| {
                if (pass) |p| {
                    p.runPass(&self._sbuf, &self._gbuf, &self._ebuf, &self._pbuf, &camera, lights, models);
                } else {
                    break;
                }
            }
        }
    };
}
