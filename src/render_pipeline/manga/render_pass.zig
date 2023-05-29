const std = @import("std");

const raylib = @import("../raylib.zig");
const rlgl = @cImport(@cInclude("rlgl.h"));

const shader = @import("../shader.zig");
const model = @import("../model.zig");
const light = @import("../light.zig");
const s_buffer = @import("../buffer/s_buffer.zig");
const g_buffer = @import("buffer/g_buffer.zig");
const e_buffer = @import("../buffer/e_buffer.zig");
const p_buffer = @import("buffer/p_buffer.zig");

const MAX_MODELS_PER_BATCH: usize = 16;
const MAX_WEIGHTS: usize = 10;

// TODO
// Render Passes
// [X] Clear
// [ ] GPU Skinning (compute)
// [ ] Depth Prepass
// [ ] Light Culling (compute)
// [X] Geometry
// [X] Edge Detection
// [ ] Pigment Manipulation
// [ ] Separable Horizontal
// [ ] Separable Vertical
// [ ] Bleeding
// [ ] Edge Manipulation
// [ ] Gaps & Overlaps
// [ ] Pigment Application
// [ ] Substrate Distortion
// [ ] Substrate Lighting
// [X] Swap
// GBuffers
// color, normal, control, depth
// EBuffers
// edge (sobel)
// PBuffers
// style, bleed, edge

fn render_quad(width: c_int, height: c_int) void {
    const x = 0.0;
    const y = 0.0;
    const w = @intToFloat(f32, width);
    const h = @intToFloat(f32, height);
    const top_left = raylib.Vector2{ .x = x, .y = y };
    const top_right = raylib.Vector2{ .x = w, .y = y };
    const bottom_left = raylib.Vector2{ .x = x, .y = h };
    const bottom_right = raylib.Vector2{ .x = w, .y = h };
    rlgl.rlBegin(rlgl.RL_QUADS);
    rlgl.rlColor4ub(255, 255, 255, 255);
    rlgl.rlNormal3f(0.0, 0.0, 1.0);

    rlgl.rlTexCoord2f(0.0, 1.0);
    rlgl.rlVertex2f(top_left.x, top_left.y);

    rlgl.rlTexCoord2f(0.0, 0.0);
    rlgl.rlVertex2f(bottom_left.x, bottom_left.y);

    rlgl.rlTexCoord2f(1.0, 0.0);
    rlgl.rlVertex2f(bottom_right.x, bottom_right.y);

    rlgl.rlTexCoord2f(1.0, 1.0);
    rlgl.rlVertex2f(top_right.x, top_right.y);
    rlgl.rlEnd();
}

pub const RenderPassClear = struct {
    fn _run(_: *const RenderPassClear, color: raylib.Color) void {
        raylib.ClearBackground(color);
    }
};

pub const RenderPassShadowmap = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassShadowmap, models: []*model.Model(shader.ToonShaderConfig)) void {
        var models_by_mat_idx: usize = 0;
        var models_by_mat = std.mem.zeroes([MAX_MODELS_PER_BATCH]?*model.Model(shader.ToonShaderConfig));

        const mats = [_]u32{ 3, 6 };
        for (mats) |mat| {
            for (models) |mdl| {
                if (mdl.model.materials[0].shader.id == mat) {
                    models_by_mat[models_by_mat_idx] = mdl;
                    models_by_mat_idx += 1;
                }
            }

            for (models_by_mat) |mdl| {
                if (mdl) |m| {
                    m.drawShadow(self._shader);
                }
            }
            models_by_mat = std.mem.zeroes([MAX_MODELS_PER_BATCH]?*model.Model(shader.ToonShaderConfig));
        }
    }
};

pub const RenderPassGeometry = struct {
    fn _run(_: *const RenderPassGeometry, sbuf: *const s_buffer.SBuffer, width: c_int, height: c_int, lights: []*light.Light, models: []*model.Model(shader.ToonShaderConfig)) void {
        var models_by_mat_idx: usize = 0;
        var models_by_mat = std.mem.zeroes([MAX_MODELS_PER_BATCH]?*model.Model(shader.ToonShaderConfig));

        const mats = [_]u32{ 3, 6 };
        for (mats) |mat| {
            for (models) |mdl| {
                if (mdl.model.materials[0].shader.id == mat) {
                    models_by_mat[models_by_mat_idx] = mdl;
                    models_by_mat_idx += 1;
                }
            }

            const l = lights[0];

            const fov = 45.0;
            const aspect = @intToFloat(f64, width) / @intToFloat(f64, height);
            const top = fov * 0.5;
            const right = top * aspect;
            const light_proj_mat = raylib.MatrixOrtho(-right, right, -top, top, 0.01, 1000.0);
            //const light_proj_mat = raylib.MatrixOrtho(-100.0, 100.0, -100.0, 100.0, 0.01, 1000.0);

            const light_view_mat = raylib.MatrixLookAt(
                l.position,
                l.target,
                raylib.Vector3{
                    .x = 0.0,
                    .y = 1.0,
                    .z = 0.0,
                },
            );
            //const light_mat = raylib.MatrixMultiply(light_proj_mat, light_view_mat);
            const light_mat = raylib.MatrixMultiply(light_view_mat, light_proj_mat);
            for (models_by_mat) |mdl| {
                if (mdl) |m| {
                    m.draw(light_mat, sbuf.shadow);
                }
            }

            models_by_mat = std.mem.zeroes([MAX_MODELS_PER_BATCH]?*model.Model(shader.ToonShaderConfig));
        }
    }
};

pub const RenderPassEdgeDetection = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassEdgeDetection, gbuf: *const g_buffer.GBuffer) void {
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("SCREEN_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.color);
        }
        if (self._shader.getUniform("NORMAL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        if (self._shader.getUniform("DEPTH_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.depth);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassPigmentManipulation = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassPigmentManipulation, gbuf: *const g_buffer.GBuffer) void {
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("SCREEN_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.color);
        }
        if (self._shader.getUniform("CONTROL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassSeparable = struct {
    _shader: shader.Shader,
    _weights: [MAX_WEIGHTS]f32,

    fn _run(self: *const RenderPassSeparable, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        if (self._shader.getUniform("CONTROL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        if (self._shader.getUniform("DEPTH_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.depth);
        }
        if (self._shader.getUniform("EDGE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, ebuf.edge);
        }
        if (self._shader.getUniform("weights")) |loc| {
            raylib.SetShaderValueV(
                self._shader.shader,
                loc,
                &self._weights,
                raylib.SHADER_UNIFORM_FLOAT,
                50,
            );
        }

        // Horizontal
        if (self._shader.getUniform("dir_x")) |loc| {
            raylib.SetShaderValueV(
                self._shader.shader,
                loc,
                &[_]f32{1.0},
                raylib.SHADER_UNIFORM_FLOAT,
                1,
            );
        }
        if (self._shader.getUniform("dir_y")) |loc| {
            raylib.SetShaderValueV(
                self._shader.shader,
                loc,
                &[_]f32{0.0},
                raylib.SHADER_UNIFORM_FLOAT,
                1,
            );
        }
        render_quad(gbuf.width, gbuf.height);
        // Vertical
        if (self._shader.getUniform("dir_x")) |loc| {
            raylib.SetShaderValueV(
                self._shader.shader,
                loc,
                &[_]f32{0.0},
                raylib.SHADER_UNIFORM_FLOAT,
                1,
            );
        }
        if (self._shader.getUniform("dir_y")) |loc| {
            raylib.SetShaderValueV(
                self._shader.shader,
                loc,
                &[_]f32{1.0},
                raylib.SHADER_UNIFORM_FLOAT,
                1,
            );
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassBleed = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassBleed, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        _ = ebuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        if (self._shader.getUniform("BLEED_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.bleed);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassEdgeManipulation = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassEdgeManipulation, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        //_ = ebuf;
        _ = pbuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.color);
        }
        if (self._shader.getUniform("EDGE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, ebuf.edge);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassGapsOverlaps = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassGapsOverlaps, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        _ = ebuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        if (self._shader.getUniform("BLEED_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.bleed);
        }
        if (self._shader.getUniform("EDGE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.darkened_edge);
        }
        if (self._shader.getUniform("CONTROL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassPigmentApplication = struct {
    _shader: shader.Shader,
    _substrate: raylib.Texture,

    fn _run(self: *const RenderPassPigmentApplication, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        _ = ebuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        if (self._shader.getUniform("CONTROL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        if (self._shader.getUniform("SUBSTRATE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, self._substrate);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassSubstrate = struct {
    _shader: shader.Shader,
    _substrate: raylib.Texture,

    fn _run(self: *const RenderPassSubstrate, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        _ = ebuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        if (self._shader.getUniform("EDGE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.darkened_edge);
        }
        if (self._shader.getUniform("CONTROL_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.control);
        }
        if (self._shader.getUniform("SUBSTRATE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, self._substrate);
        }
        if (self._shader.getUniform("DEPTH_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, gbuf.depth);
        }
        render_quad(gbuf.width, gbuf.height);
    }
};

pub const RenderPassSwap = struct {
    _shader: shader.Shader,

    fn _run(self: *const RenderPassSwap, sbuf: *const s_buffer.SBuffer, gbuf: *const g_buffer.GBuffer, ebuf: *const e_buffer.EBuffer, pbuf: *const p_buffer.PBuffer) void {
        _ = sbuf;
        _ = gbuf;
        //_ = pbuf;
        _ = ebuf;
        raylib.BeginShaderMode(self._shader.shader);
        defer raylib.EndShaderMode();
        if (self._shader.getUniform("STYLE_TEXTURE")) |loc| {
            raylib.SetShaderValueTexture(self._shader.shader, loc, pbuf.style);
        }
        const width = raylib.GetRenderWidth(); //pbuf.width * raylib.RenderTextureDPI();
        const height = raylib.GetRenderHeight(); //pbuf.height * raylib.RenderTextureDPI();

        rlgl.rlEnableFramebuffer(0); // Enable default FBO render target
        // Set viewport and RLGL internal framebuffer size
        rlgl.rlViewport(0, 0, width, height);
        rlgl.rlSetFramebufferWidth(width);
        rlgl.rlSetFramebufferHeight(height);

        rlgl.rlMatrixMode(rlgl.RL_PROJECTION); // Switch to projection matrix
        rlgl.rlLoadIdentity(); // Reset current matrix (projection)

        // Set orthographic projection to current framebuffer size
        // NOTE: Configured top-left corner as (0, 0)
        rlgl.rlOrtho(0, @intToFloat(f32, width), @intToFloat(f32, height), 0, 0.0, 1.0);

        rlgl.rlMatrixMode(rlgl.RL_MODELVIEW); // Switch back to modelview matrix
        rlgl.rlLoadIdentity(); // Reset current matrix (modelview)
        render_quad(width, height);
    }
};

pub const RenderPass = union(enum) {
    Clear: RenderPassClear,
    Shadowmap: RenderPassShadowmap,
    Geometry: RenderPassGeometry,
    EdgeDetection: RenderPassEdgeDetection,
    PigmentManipulation: RenderPassPigmentManipulation,
    Separable: RenderPassSeparable,
    Bleed: RenderPassBleed,
    EdgeManipulation: RenderPassEdgeManipulation,
    GapsOverlaps: RenderPassGapsOverlaps,
    PigmentApplication: RenderPassPigmentApplication,
    Substrate: RenderPassSubstrate,
    Swap: RenderPassSwap,

    pub fn init_clear() RenderPass {
        return RenderPass{
            .Clear = RenderPassClear{},
        };
    }

    pub fn init_shadowmap(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{};
        return RenderPass{
            .Shadowmap = RenderPassShadowmap{
                ._shader = shader.Shader.init("shadowmap", 0, "src/shaders/shadowmap.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_geometry() RenderPass {
        return RenderPass{
            .Geometry = RenderPassGeometry{},
        };
    }

    pub fn init_edge_detection(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "SCREEN_TEXTURE" },
            shader.ShaderUniform{ .name = "NORMAL_TEXTURE" },
            shader.ShaderUniform{ .name = "DEPTH_TEXTURE" },
            shader.ShaderUniform{ .name = "sdf_scale" },
        };
        return RenderPass{
            .EdgeDetection = RenderPassEdgeDetection{
                ._shader = shader.Shader.init("edge_detection", 0, "src/shaders/edge_detection.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_pigment_manipulation(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "SCREEN_TEXTURE" },
            shader.ShaderUniform{ .name = "CONTROL_TEXTURE" },
            shader.ShaderUniform{ .name = "substrate" },
        };
        return RenderPass{
            .PigmentManipulation = RenderPassPigmentManipulation{
                ._shader = shader.Shader.init("pigment_manipulation", 0, "src/shaders/watercolor/pigment_manipulation.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_separable(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "CONTROL_TEXTURE" },
            shader.ShaderUniform{ .name = "DEPTH_TEXTURE" },
            shader.ShaderUniform{ .name = "EDGE_TEXTURE" },
            shader.ShaderUniform{ .name = "dir_x" },
            shader.ShaderUniform{ .name = "dir_y" },
            shader.ShaderUniform{ .name = "bleeding_threshold" },
            shader.ShaderUniform{ .name = "bleeding_radius" },
            shader.ShaderUniform{ .name = "edge_darkening_kernel" },
            shader.ShaderUniform{ .name = "gaps_overlaps_kernel" },
            shader.ShaderUniform{ .name = "weights" },
        };

        const bleeding_radius = 5;
        var sigma = @intToFloat(f32, bleeding_radius) * 2.0;
        var norm_divisor: f32 = 0.0;
        var weights: [MAX_WEIGHTS]f32 = std.mem.zeroes([MAX_WEIGHTS]f32);
        var a: i32 = -bleeding_radius;
        while (a < bleeding_radius) : (a += 1) {
            var weight = 0.15915 * std.math.exp(-0.5 * @intToFloat(f32, a) * @intToFloat(f32, a) / (sigma * sigma)) / sigma;
            norm_divisor += weight;
            weights[@intCast(usize, a + bleeding_radius)] = weight;
        }
        a = -bleeding_radius;
        while (a < bleeding_radius) : (a += 1) {
            weights[@intCast(usize, a + bleeding_radius)] /= norm_divisor;
        }
        return RenderPass{
            .Separable = RenderPassSeparable{
                ._shader = shader.Shader.init("separable", 0, "src/shaders/watercolor/separable.fs", &uniforms, allocator),
                ._weights = weights,
            },
        };
    }

    pub fn init_bleed(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "BLEED_TEXTURE" },
        };
        return RenderPass{
            .Bleed = RenderPassBleed{
                ._shader = shader.Shader.init("bleed", 0, "src/shaders/watercolor/bleed.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_edge_manipulation(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "EDGE_TEXTURE" },
        };
        return RenderPass{
            .EdgeManipulation = RenderPassEdgeManipulation{
                ._shader = shader.Shader.init("edge_manipulation", 0, "src/shaders/manga/edge_manipulation.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_gaps_overlaps(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "EDGE_TEXTURE" },
            shader.ShaderUniform{ .name = "BLEED_TEXTURE" },
            shader.ShaderUniform{ .name = "CONTROL_TEXTURE" },
            shader.ShaderUniform{ .name = "substrate" },
            shader.ShaderUniform{ .name = "go_radius" },
        };
        return RenderPass{
            .GapsOverlaps = RenderPassGapsOverlaps{
                ._shader = shader.Shader.init("gaps_overlaps", 0, "src/shaders/watercolor/gaps_overlaps.fs", &uniforms, allocator),
            },
        };
    }

    pub fn init_pigment_application(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "CONTROL_TEXTURE" },
            shader.ShaderUniform{ .name = "SUBSTRATE_TEXTURE" },
            shader.ShaderUniform{ .name = "substrate" },
            shader.ShaderUniform{ .name = "strength" },
            shader.ShaderUniform{ .name = "density" },
            shader.ShaderUniform{ .name = "intensity" },
        };
        return RenderPass{
            .PigmentApplication = RenderPassPigmentApplication{
                ._shader = shader.Shader.init("pigment_application", 0, "src/shaders/watercolor/pigment_application.fs", &uniforms, allocator),
                ._substrate = raylib.LoadTexture("assets/textures/substrates/coldPress_Fabriano_1k.png"),
            },
        };
    }

    pub fn init_substrate(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            shader.ShaderUniform{ .name = "EDGE_TEXTURE" },
            shader.ShaderUniform{ .name = "CONTROL_TEXTURE" },
            shader.ShaderUniform{ .name = "SUBSTRATE_TEXTURE" },
            shader.ShaderUniform{ .name = "DEPTH_TEXTURE" },
            shader.ShaderUniform{ .name = "substrate" },
            shader.ShaderUniform{ .name = "dir" },
            shader.ShaderUniform{ .name = "tilt" },
        };
        return RenderPass{
            .Substrate = RenderPassSubstrate{
                ._shader = shader.Shader.init("substrate", 0, "src/shaders/watercolor/substrate.fs", &uniforms, allocator),
                ._substrate = raylib.LoadTexture("assets/textures/substrates/coldPress_Fabriano_1k.png"),
            },
        };
    }

    pub fn init_swap(allocator: std.mem.Allocator) RenderPass {
        const uniforms = [_]shader.ShaderUniform{
            shader.ShaderUniform{ .name = "STYLE_TEXTURE" },
            //shader.ShaderUniform{ .name = "NORMAL_TEXTURE" },
            //shader.ShaderUniform{ .name = "DEPTH_TEXTURE" },
            //shader.ShaderUniform{ .name = "EDGE_TEXTURE" },
            //shader.ShaderUniform{ .name = "BLEED_TEXTURE" },
        };
        return RenderPass{
            .Swap = RenderPassSwap{
                ._shader = shader.Shader.init("output", 0, "src/shaders/output.fs", &uniforms, allocator),
            },
        };
    }

    pub fn begin(_: *const RenderPass, camera: *const raylib.Camera) void {
        raylib.BeginMode3D(camera.*);
    }

    pub fn end(_: *const RenderPass) void {
        raylib.EndMode3D();
    }

    pub fn runPass(
        self: *const RenderPass,
        sbuf: *const s_buffer.SBuffer,
        gbuf: *const g_buffer.GBuffer,
        ebuf: *const e_buffer.EBuffer,
        pbuf: *const p_buffer.PBuffer,
        camera: *const raylib.Camera,
        lights: []*light.Light,
        models: []*model.Model(shader.ToonShaderConfig),
    ) void {
        switch (self.*) {
            .Clear => |pass| {
                // Shadowmap
                sbuf.beginBufferMode();
                pass._run(raylib.BLACK);
                sbuf.endBufferMode();
                // Geometry
                gbuf.beginBufferMode();
                pass._run(raylib.SKYBLUE);
                gbuf.endBufferMode();
                // Edge
                ebuf.beginBufferMode();
                pass._run(raylib.BLACK);
                ebuf.endBufferMode();
                // Post Process
                pbuf.beginBufferMode();
                pass._run(raylib.WHITE);
                pbuf.endBufferMode();
            },
            .Shadowmap => |pass| {
                for (lights) |l| {
                    if (l.cast_shadow == 0) {
                        continue;
                    }
                    var shadow_camera = raylib.Camera{
                        .position = l.position,
                        .target = l.target,
                        .up = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
                        .fovy = 45.0,
                        .projection = raylib.CAMERA_ORTHOGRAPHIC,
                    };
                    sbuf.beginBufferMode();
                    self.begin(&shadow_camera);
                    pass._run(models);
                    self.end();
                    sbuf.endBufferMode();
                }
            },
            .Geometry => |pass| {
                gbuf.beginBufferMode();
                self.begin(camera);
                pass._run(sbuf, gbuf.width, gbuf.height, lights, models);
                self.end();
                gbuf.endBufferMode();
            },
            .EdgeDetection => |pass| {
                ebuf.beginBufferMode();
                pass._run(gbuf);
                ebuf.endBufferMode();
            },
            .PigmentManipulation => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf);
                pbuf.endBufferMode();
            },
            .Separable => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .Bleed => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .EdgeManipulation => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .GapsOverlaps => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .PigmentApplication => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .Substrate => |pass| {
                pbuf.beginBufferMode();
                pass._run(gbuf, ebuf, pbuf);
                pbuf.endBufferMode();
            },
            .Swap => |pass| pass._run(sbuf, gbuf, ebuf, pbuf),
        }
    }
};
