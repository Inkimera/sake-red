const raylib = @import("raylib.zig");
const shader = @import("shader.zig");

pub const Model = struct {
    model: raylib.Model,
    shader: *shader.Shader,
    shader_config: shader.PainterlyShaderConfig,
    //shader_config: shader.ToonShaderConfig,
    transform: raylib.Vector3,

    pub fn init(model: raylib.Model, s: *shader.Shader) Model {
        if (s.getUniform("ALBEDO_TEXTURE")) |loc| {
            s.shader.locs[raylib.SHADER_LOC_MAP_DIFFUSE] = loc;
        }
        if (s.getUniform("SPECULAR_TEXTURE")) |loc| {
            s.shader.locs[raylib.SHADER_LOC_MAP_SPECULAR] = loc;
        }
        //if (s.getUniform("NORMAL_TEXTURE")) |loc| {
        //    s.shader.locs[raylib.SHADER_LOC_MAP_DIFFUSE + 2] = loc;
        //}
        if (s.getUniform("CONTROL_TEXTURE")) |loc| {
            s.shader.locs[raylib.SHADER_LOC_MAP_DIFFUSE + 3] = loc;
        }
        var i: usize = 0;
        while (i < model.meshCount) : (i += 1) {
            model.materials[@intCast(usize, model.meshMaterial[i])].shader = s.shader;
        }
        return Model{
            .model = model,
            .shader = s,
            .shader_config = shader.PainterlyShaderConfig.default(),
            //.shader_config = shader.ToonShaderConfig.default(),
            .transform = raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        };
    }

    pub fn translate(self: *Model, vec: raylib.Vector3) void {
        self.transform = raylib.Vector3Add(self.transform, vec);
    }
};
