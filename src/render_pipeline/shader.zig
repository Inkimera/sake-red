const std = @import("std");
const raylib = @import("raylib.zig");

pub const ShaderUniform = struct {
    name: [*c]const u8,
};

pub const PainterlyShaderConfig = struct {
    ambient: [3]f32,
    albedo: [3]f32,
    cangiante: [3]f32,
    shadow: [3]f32,
    emission: [3]f32,
    substrate: [3]f32,

    diffuse_factor: f32,
    shade_wrap: f32,
    dark_edges: f32,
    dilute: f32,
    dilute_area: f32,

    specular_intensity: f32,
    specular_diffuse: f32,
    specular_transparency: f32,
    specular_depth: f32,
    high_area: f32,

    disable_lighting: c_int,

    pub fn default() PainterlyShaderConfig {
        return PainterlyShaderConfig{
            .ambient = [3]f32{ 0.3, 0.3, 0.3 },
            .albedo = [3]f32{ 1.0, 1.0, 1.0 },
            .cangiante = [3]f32{ 0.2, 0.2, 0.2 },
            .shadow = [3]f32{ 0.0, 0.0, 0.0 },
            .emission = [3]f32{ 0.0, 0.0, 0.0 },
            .substrate = [3]f32{ 1.0, 1.0, 1.0 },
            .diffuse_factor = 0.8,
            .shade_wrap = 0.5,
            .dark_edges = 0.5,
            .dilute = 0.8,
            .dilute_area = 0.9,
            .high_area = 0.0,
            .specular_intensity = 0.35,
            .specular_diffuse = 0.99,
            .specular_transparency = 0.75,
            .specular_depth = 100.0,
            .disable_lighting = 0,
        };
    }

    pub fn uniforms() [18]ShaderUniform {
        return [_]ShaderUniform{
            ShaderUniform{ .name = "camera" },
            ShaderUniform{ .name = "ambient" },
            ShaderUniform{ .name = "albedo" },
            ShaderUniform{ .name = "cangiante" },
            ShaderUniform{ .name = "shadow" },
            ShaderUniform{ .name = "emission" },
            ShaderUniform{ .name = "substrate" },
            ShaderUniform{ .name = "diffuse_factor" },
            ShaderUniform{ .name = "shade_wrap" },
            ShaderUniform{ .name = "dark_edges" },
            ShaderUniform{ .name = "dilute" },
            ShaderUniform{ .name = "dilute_area" },
            ShaderUniform{ .name = "high_area" },
            ShaderUniform{ .name = "specular_intensity" },
            ShaderUniform{ .name = "specular_diffuse" },
            ShaderUniform{ .name = "specular_transparency" },
            ShaderUniform{ .name = "specular_depth" },
            ShaderUniform{ .name = "disable_lighting" },
        };
    }

    pub fn apply(self: *PainterlyShaderConfig, shader: *Shader) void {
        shader.setUniform("albedo", &self.albedo, raylib.SHADER_UNIFORM_VEC3);
        shader.setUniform("cangiante", &self.cangiante, raylib.SHADER_UNIFORM_VEC3);
        shader.setUniform("shadow", &self.shadow, raylib.SHADER_UNIFORM_VEC3);
        shader.setUniform("emission", &self.emission, raylib.SHADER_UNIFORM_VEC3);
        shader.setUniform("substrate", &self.substrate, raylib.SHADER_UNIFORM_VEC3);
        shader.setUniform("diffuse_factor", &self.diffuse_factor, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("shade_wrap", &self.shade_wrap, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("dark_edges", &self.dark_edges, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("dilute", &self.dilute, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("dilute_area", &self.dilute_area, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("high_area", &self.high_area, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("specular_intensity", &self.specular_intensity, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("specular_diffuse", &self.specular_diffuse, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("specular_transparency", &self.specular_transparency, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("specular_depth", &self.specular_depth, raylib.SHADER_UNIFORM_FLOAT);
        shader.setUniform("disable_lighting", &self.disable_lighting, raylib.SHADER_UNIFORM_INT);
    }
};

pub const Shader = struct {
    id: []const u8,
    shader: raylib.Shader,
    uniforms: std.StringHashMap(c_int),

    pub fn init(id: []const u8, vs_source: [*c]const u8, fs_source: [*c]const u8, uniforms: []const ShaderUniform, allocator: std.mem.Allocator) Shader {
        var umap = std.StringHashMap(c_int).init(allocator);
        // NOTE: "matModel" location name is automatically assigned on shader loading,
        const shader = raylib.LoadShader(vs_source, fs_source);
        for (uniforms) |u| {
            //shader.locs[@enumToInt(u.uidx)] = raylib.GetShaderLocation(shader, u.name);
            umap.put(std.mem.sliceTo(u.name, 0x00), raylib.GetShaderLocation(shader, u.name)) catch {
                std.debug.print("Failed to set {s}\n", .{u.name});
            };
        }
        return Shader{
            .id = id,
            .shader = shader,
            .uniforms = umap,
        };
    }

    pub fn deinit(self: *Shader) void {
        self.uniforms.deinit();
    }

    pub fn setUniform(self: *Shader, uniform: []const u8, value: *const anyopaque, value_type: c_int) void {
        if (self.uniforms.get(uniform)) |loc| {
            raylib.SetShaderValue(
                self.shader,
                loc,
                value,
                value_type,
            );
        }
    }

    pub fn getUniform(self: *const Shader, uniform: []const u8) ?c_int {
        if (self.uniforms.get(uniform)) |loc| {
            return loc;
        } else {
            return null;
        }
    }
};
