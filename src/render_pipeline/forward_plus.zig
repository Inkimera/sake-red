const std = @import("std");
const raylib = @import("raylib.zig");

const s_buffer = @import("buffer/s_buffer.zig");
const e_buffer = @import("buffer/e_buffer.zig");
const light = @import("light.zig");
const model = @import("model.zig");

const MAX_PASSES: usize = 16;

pub fn ForwardPlus(comptime r: type, comptime shader_config: type, comptime GBuffer: type, comptime PBuffer: type) type {
    return struct {
        const Self = @This();

        _sbuf: s_buffer.SBuffer,
        _gbuf: GBuffer,
        _ebuf: e_buffer.EBuffer,
        _pbuf: PBuffer,
        _pass_count: usize,
        _passes: [MAX_PASSES]?r,

        pub fn init() Self {
            return Self{
                ._sbuf = s_buffer.SBuffer.init(),
                ._gbuf = GBuffer.init(),
                ._ebuf = e_buffer.EBuffer.init(),
                ._pbuf = PBuffer.init(),
                ._pass_count = 0,
                ._passes = std.mem.zeroes([MAX_PASSES]?r),
            };
        }

        pub fn resize(self: *Self) void {
            if (self._gbuf.color.width != raylib.GetRenderWidth() or self._gbuf.color.height != raylib.GetRenderHeight()) {
                self._sbuf.deinit();
                self._sbuf = s_buffer.SBuffer.init();
                self._gbuf.deinit();
                self._gbuf = GBuffer.init();
                self._ebuf.deinit();
                self._ebuf = e_buffer.EBuffer.init();
                self._pbuf.deinit();
                self._pbuf = PBuffer.init();
            }
        }

        pub fn addPass(self: *Self, pass: r) void {
            self._passes[self._pass_count] = pass;
            self._pass_count += 1;
        }

        pub fn render(self: *const Self, camera: raylib.Camera, lights: []*light.Light, models: []*model.Model(shader_config)) void {
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
