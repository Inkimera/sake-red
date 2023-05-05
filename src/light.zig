const raylib = @import("render_pipeline/raylib.zig");

pub const MAX_LIGHTS: i32 = 4;
var lightsCount: i32 = 0;

// Light data
pub const Light = struct {
    light_type: u32,
    enabled: i32,
    position: raylib.Vector3,
    target: raylib.Vector3,
    color: raylib.Color,
    intensity: f32,
    attenuation: f32,

    // Shader locations
    enabledLoc: i32,
    typeLoc: i32,
    positionLoc: i32,
    targetLoc: i32,
    colorLoc: i32,
    intensityLoc: i32,
    attenuationLoc: i32,
};

// Light type
pub const LightType = enum(u32) {
    LIGHT_DIRECTIONAL = 0,
    LIGHT_POINT,
};

// Create a light and get shader locations
pub fn CreateLight(light_type: u32, position: raylib.Vector3, target: raylib.Vector3, color: raylib.Color, shader: raylib.Shader) Light {
    const light = Light{
        .enabled = 1,
        .light_type = light_type,
        .position = position,
        .target = target,
        .color = color,
        .intensity = 3.0,
        .attenuation = 1.0,
        .enabledLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].enabled", lightsCount)),
        .typeLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].light_type", lightsCount)),
        .positionLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].position", lightsCount)),
        .targetLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].target", lightsCount)),
        .colorLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].color", lightsCount)),
        .intensityLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].intensity", lightsCount)),
        .attenuationLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].attenuation", lightsCount)),
    };
    UpdateLightValues(shader, light);
    lightsCount += 1;
    return light;
}

pub fn UpdateLightValues(shader: raylib.Shader, light: Light) void {
    // Send to shader light enabled state and type
    raylib.SetShaderValue(shader, light.enabledLoc, &light.enabled, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(shader, light.typeLoc, &light.light_type, raylib.SHADER_UNIFORM_INT);

    // Send to shader light position values
    const position = [_]f32{ light.position.x, light.position.y, light.position.z };
    raylib.SetShaderValue(shader, light.positionLoc, &position, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light target position values
    const target = [_]f32{ light.target.x, light.target.y, light.target.z };
    raylib.SetShaderValue(shader, light.targetLoc, &target, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light color values
    const color = [_]f32{ @intToFloat(f32, light.color.r) / 255.0, @intToFloat(f32, light.color.g) / 255.0, @intToFloat(f32, light.color.b) / 255.0, @intToFloat(f32, light.color.a) / 255.0 };
    raylib.SetShaderValue(shader, light.colorLoc, &color, raylib.SHADER_UNIFORM_VEC4);

    // Send to shader light attenuation value
    raylib.SetShaderValue(shader, light.attenuationLoc, &light.attenuation, raylib.SHADER_UNIFORM_FLOAT);

    // Send to shader light intensity value
    raylib.SetShaderValue(shader, light.intensityLoc, &light.intensity, raylib.SHADER_UNIFORM_FLOAT);
}
