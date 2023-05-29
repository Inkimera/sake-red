const std = @import("std");

const raylib = @import("raylib.zig");
const shader = @import("shader.zig");

pub fn Model(comptime shader_config: type) type {
    return struct {
        const Self = @This();
        model: raylib.Model,
        shader: *shader.Shader,
        shader_config: shader_config,
        shader_config_path: ?[]const u8,
        transform: raylib.Vector3,

        pub fn init(
            model: raylib.Model,
            s: *shader.Shader,
            config_path: ?[]const u8,
        ) Self {
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
            if (s.getUniform("SHADOWMAP_TEXTURE")) |loc| {
                s.shader.locs[raylib.SHADER_LOC_MAP_DIFFUSE + 4] = loc;
            }
            var i: usize = 0;
            while (i < model.meshCount) : (i += 1) {
                model.materials[@intCast(usize, model.meshMaterial[i])].shader = s.shader;
            }
            return .{
                .model = model,
                .shader = s,
                .shader_config = shader_config.default(),
                .shader_config_path = config_path,
                .transform = raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
            };
        }

        pub fn reload_shader_config(self: *Self, allocator: std.mem.Allocator) bool {
            //const data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/painterly.json", 512);
            if (self.shader_config_path) |path| {
                if (std.fs.cwd().readFileAlloc(allocator, path, 512)) |data| {
                    defer allocator.free(data);
                    var stream = std.json.TokenStream.init(data);
                    //var config = try std.json.parse(shader.PainterlyShaderConfig, &stream, .{ .allocator = allocator });
                    @setEvalBranchQuota(2000); // WTF zig
                    if (std.json.parse(shader_config, &stream, .{ .allocator = allocator })) |config| {
                        self.shader_config = config;
                        return true;
                    } else |_| {}
                } else |_| {}
            }
            return false;
        }

        pub fn translate(self: *Self, vec: raylib.Vector3) void {
            self.transform = raylib.Vector3Add(self.transform, vec);
        }

        pub fn drawShadow(self: *Self, shadow_shader: shader.Shader) void {
            const m_shader = self.model.materials[0].shader;
            self.model.materials[0].shader = shadow_shader.shader;
            raylib.DrawModel(self.model, self.transform, 1.0, raylib.WHITE);
            self.model.materials[0].shader = m_shader;
        }

        pub fn draw(self: *Self, light_mat: raylib.Matrix, shadow_texture: raylib.Texture) void {
            self.shader_config.apply(self.shader);
            self.shader.setUniformMatrix("matLight", light_mat);
            self.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 4].texture = shadow_texture;
            raylib.DrawModel(self.model, self.transform, 1.0, raylib.WHITE);
        }
    };
}
