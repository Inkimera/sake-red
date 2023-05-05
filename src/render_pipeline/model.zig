const raylib = @import("raylib.zig");
const shader = @import("shader.zig");

pub const Model = struct {
    model: raylib.Model,
    shader: *shader.Shader,
    shader_config: shader.PainterlyShaderConfig,
    transform: raylib.Vector3,

    pub fn init(model: raylib.Model, s: *shader.Shader) Model {
        return Model{
            .model = model,
            .shader = s,
            .shader_config = shader.PainterlyShaderConfig.default(),
            .transform = raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        };
    }

    pub fn translate(self: *Model, vec: raylib.Vector3) void {
        self.transform = raylib.Vector3Add(self.transform, vec);
    }
};
