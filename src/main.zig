const std = @import("std");
const raylib = @import("render_pipeline/raylib.zig");
//const toml = @import("vendor/zig-toml/src/main.zig");

const light = @import("render_pipeline/light.zig");
const MAX_LIGHTS = light.MAX_LIGHTS;
const Light = light.Light;
const LightType = light.LightType;
const CreateLight = light.CreateLight;
const UpdateLightValues = light.UpdateLightValues;

const shader = @import("render_pipeline/shader.zig");
const forward_plus = @import("render_pipeline/forward_plus.zig");
const watercolor_render_pass = @import("render_pipeline/watercolor/render_pass.zig");
const manga_render_pass = @import("render_pipeline/manga/render_pass.zig");
const manga_gbuffer = @import("render_pipeline/manga/buffer/g_buffer.zig");
const manga_pbuffer = @import("render_pipeline/manga/buffer/p_buffer.zig");
const model = @import("render_pipeline/model.zig");

pub fn main() !void {
    const screenWidth = raylib.GetRenderWidth();
    const screenHeight = raylib.GetRenderHeight();

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_HIGHDPI);
    raylib.InitWindow(screenWidth, screenHeight, "SakaRed");
    raylib.SetWindowState(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.SetExitKey(raylib.KEY_NULL);
    defer raylib.CloseWindow();

    var camera = raylib.Camera{
        .position = raylib.Vector3{ .x = 2.0, .y = 4.0, .z = 6.0 }, // Camera position
        .target = raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, // Camera looking at point
        .up = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 }, // Camera up vector (rotation towards target)
        .fovy = 45.0, // Camera field-of-view Y
        .projection = raylib.CAMERA_PERSPECTIVE, // Camera projection type
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //const shader_config_type = shader.PainterlyShaderConfig;
    //var model_shader = shader.Shader.init(
    //    "painterly",
    //    "src/shaders/watercolor/painterly.vs",
    //    "src/shaders/watercolor/painterly.fs",
    //    &shader.PainterlyShaderConfig.uniforms(),
    //    allocator,
    //);
    //defer model_shader.deinit();
    //var rp = watercolor_forward_plus(allocator);

    const shader_config_type = shader.ToonShaderConfig;
    var model_shader = shader.Shader.init(
        "toon",
        "src/shaders/manga/toon.vs",
        "src/shaders/manga/toon.fs",
        &shader.ToonShaderConfig.uniforms(),
        allocator,
    );
    defer model_shader.deinit();
    var rp = manga_forward_plus(allocator);

    var plane = model.Model(shader_config_type).init(
        //raylib.LoadModelFromMesh(raylib.GenMeshPlane(100.0, 100.0, 10, 10)),
        raylib.LoadModel("assets/models/basic_slope/basic_slope.obj"),
        &model_shader,
        "assets/models/basic_slope/toon.json",
    );
    //var monkey = model.Model(shader_config_type).init(
    //    raylib.LoadModel("assets/models/demo/demo.glb"),
    //    &model_shader,
    //    //"assets/models/demo/painterly.json",
    //    "assets/models/demo/toon.json",
    //);
    //var animsCount: c_uint = 0;
    //var anims = raylib.LoadModelAnimations("assets/models/demo/demo.glb", &animsCount);
    //var animFrameCounter: c_int = 0;

    var monkey = model.Model(shader_config_type).init(
        raylib.LoadModel("assets/models/robot_ball/robot_ball.obj"),
        &model_shader,
        //"assets/models/robot_ball/painterly.json",
        "assets/models/robot_ball/toon.json",
    );

    var cube = model.Model(shader_config_type).init(
        raylib.LoadModelFromMesh(raylib.GenMeshCube(2.0, 2.0, 2.0)),
        &model_shader,
        //"assets/models/cube/painterly.json",
        "assets/models/cube/toon.json",
    );
    var sphere = model.Model(shader_config_type).init(
        raylib.LoadModelFromMesh(raylib.GenMeshSphere(1.0, 32.0, 32.0)),
        &model_shader,
        //"assets/models/sphere/painterly.json",
        "assets/models/sphere/toon.json",
    );

    _ = monkey.reload_shader_config(allocator);
    _ = cube.reload_shader_config(allocator);
    _ = sphere.reload_shader_config(allocator);

    plane.translate(raylib.Vector3{ .x = 0.0, .y = -10.0, .z = 0.0 });
    monkey.translate(raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 });
    cube.translate(raylib.Vector3{ .x = 4.0, .y = 1.0, .z = 0.0 });
    sphere.translate(raylib.Vector3{ .x = -4.0, .y = 1.0, .z = 0.0 });

    plane.shader_config.albedo = [3]f32{ 1.0, 1.0, 1.0 };
    plane.shader_config.ambient = [3]f32{ 0.0, 0.0, 0.0 };
    plane.shader_config.emission = [3]f32{ 0.0, 0.0, 0.0 };
    plane.shader_config.shadow = [3]f32{ 0.05, 0.0, 0.05 };
    //plane.shader_config.specular_intensity = 0.2;
    //plane.shader_config.specular_transparency = 0.6;
    plane.shader_config.uv_wrap_x = 10.0;
    plane.shader_config.uv_wrap_y = 10.0;
    plane.shader_config.disable_lighting = 0;

    //cube.shader_config.specular_intensity = 0.4;

    //sphere.shader_config.uv_wrap_x = 4.0;
    //sphere.shader_config.uv_wrap_y = 4.0;

    const control_base = raylib.LoadTexture("assets/textures/control_base.png");
    plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/snow.png");
    //plane.model.materials[0].maps[raylib.MATERIAL_MAP_SPECULAR].texture = raylib.LoadTexture("assets/textures/bronze/rusted/specular.png");
    //plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/textures/plane_control.png");
    //raylib.SetTextureFilter(plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture, raylib.TEXTURE_FILTER_TRILINEAR);

    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/models/robot_ball/robot_ball_albedo.png");
    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_SPECULAR].texture = raylib.LoadTexture("assets/models/robot_ball/robot_ball_specular.png");
    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/robot_ball/robot_ball_control.png");
    raylib.SetTextureFilter(monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture, raylib.TEXTURE_FILTER_TRILINEAR);
    raylib.SetTextureFilter(monkey.model.materials[0].maps[raylib.MATERIAL_MAP_SPECULAR].texture, raylib.TEXTURE_FILTER_TRILINEAR);
    raylib.SetTextureFilter(monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture, raylib.TEXTURE_FILTER_TRILINEAR);

    //monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/bronze/rusted/albedo.png");
    //monkey.model.materials[0].maps[raylib.MATERIAL_MAP_SPECULAR].texture = raylib.LoadTexture("assets/textures/bronze/rusted/specular.png");
    //monkey.model.materials[1].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = control_base;

    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/bronze/rusted/albedo.png");
    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/bronze/rusted/specular.png");
    cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = control_base;

    //sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/gold/painted/albedo.png");
    //sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/gold/painted/specular.png");
    sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = control_base;

    // Lights
    var l2 = model.Model(shader_config_type).init(
        raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.1, 16.0, 16.0)),
        &model_shader,
        null,
    );
    l2.translate(raylib.Vector3{ .x = 4.0, .y = 5.0, .z = 2.0 });
    //l2.model.materials[0].shader = painterly_shader.shader;
    l2.shader_config.emission = [3]f32{ 1.0, 0.2, 0.2 };
    //l2.shader_config.dark_edges = 0.0;
    l2.shader_config.disable_lighting = 1;
    l2.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = control_base;

    var l3 = model.Model(shader_config_type).init(
        raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.1, 16.0, 16.0)),
        &model_shader,
        null,
    );
    l3.translate(raylib.Vector3{ .x = -4.0, .y = 5.0, .z = -2.0 });
    //l3.model.materials[0].shader = painterly_shader.shader;
    l3.shader_config.emission = [3]f32{ 0.0, 0.5, 1.0 };
    //l3.shader_config.dark_edges = 0.0;
    l3.shader_config.disable_lighting = 1;

    var models = [_]*model.Model(shader_config_type){ &plane, &monkey, &cube, &sphere, &l2, &l3 };

    var dl = CreateLight(
        @enumToInt(LightType.LIGHT_DIRECTIONAL),
        raylib.Vector3{ .x = 0.0, .y = 10.0, .z = 20.0 },
        raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
        raylib.WHITE,
        model_shader.shader,
    );
    //var pl1 = CreateLight(
    //    @enumToInt(LightType.LIGHT_POINT),
    //    l2.transform,
    //    raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
    //    raylib.RED,
    //    model_shader.shader,
    //);
    //var pl2 = CreateLight(
    //    @enumToInt(LightType.LIGHT_POINT),
    //    l3.transform,
    //    raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
    //    raylib.BLUE,
    //    model_shader.shader,
    //);
    // Create lights
    var lights = [_]*Light{
        &dl,
        //&pl1,
        //&pl2,
    };
    // 0
    lights[0].attenuation = 0.25;
    lights[0].intensity = 0.01;
    lights[0].cast_shadow = 1;
    lights[0].enabled = 1;
    //// 1
    //lights[1].attenuation = 7.0;
    //lights[1].intensity = 2.0;
    //lights[1].cast_shadow = 0;
    //lights[1].enabled = 1;
    //// 2
    //lights[2].attenuation = 7.0;
    //lights[2].intensity = 1.0;
    //lights[2].cast_shadow = 0;
    //lights[2].enabled = 1;

    raylib.SetTargetFPS(120);
    var capture_mouse = false;
    while (!raylib.WindowShouldClose()) {
        if (raylib.IsKeyPressed(raylib.KEY_ESCAPE) and raylib.IsCursorOnScreen()) {
            if (capture_mouse) {
                raylib.EnableCursor();
            } else {
                raylib.DisableCursor();
            }
            capture_mouse = !capture_mouse;
        }
        if (capture_mouse) {
            raylib.UpdateCamera(&camera, raylib.CAMERA_PERSPECTIVE);
            if (raylib.IsKeyDown(raylib.KEY_LEFT_CONTROL) and raylib.IsKeyPressed(raylib.KEY_R)) {
                for (models) |m| {
                    if (m.reload_shader_config(allocator)) {
                        std.debug.print("Shader Config {?s} Updated\n", .{m.shader_config_path});
                    } else {
                        std.debug.print("Shader Config {?s} Invalid\n", .{m.shader_config_path});
                    }
                }
            }
        }

        monkey.translate(raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.002 });
        if (monkey.transform.z > 5.0) {
            monkey.transform = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }

        cube.translate(raylib.Vector3{ .x = 0.001, .y = 0.0, .z = 0.001 });
        if (cube.transform.z > 5.0) {
            cube.transform = raylib.Vector3{ .x = 4.0, .y = 1.0, .z = 0.0 };
        }

        sphere.translate(raylib.Vector3{ .x = -0.002, .y = 0.0, .z = 0.003 });
        if (sphere.transform.z > 10.0) {
            sphere.transform = raylib.Vector3{ .x = -4.0, .y = 1.0, .z = 0.0 };
        }

        //lights[1].attenuation -= 0.001;
        //lights[1].intensity -= 0.01;
        //if (lights[1].intensity < 0.2) {
        //    lights[1].intensity = 1.0;
        //}
        //if (lights[1].attenuation < 6.5) {
        //    lights[1].attenuation = 7.0;
        //}

        //animFrameCounter += 1;
        //raylib.UpdateModelAnimation(monkey.model, anims[2], animFrameCounter);
        //if (animFrameCounter >= anims[2].frameCount) {
        //    animFrameCounter = 0;
        //}

        var cameraPos = [3]f32{ camera.position.x, camera.position.y, camera.position.z };
        model_shader.setUniform("camera", &cameraPos, raylib.SHADER_UNIFORM_VEC3);

        for (lights) |l| {
            UpdateLightValues(model_shader.shader, l.*);
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();
        // Render
        rp.render(camera, &lights, &models);
        // Debug
        raylib.DrawFPS(10.0, 10.0);
        rp.resize();
    }
}

fn watercolor_forward_plus(allocator: std.mem.Allocator) forward_plus.ForwardPlus(watercolor_render_pass.RenderPass, shader.PainterlyShaderConfig) {
    const clear_pass = watercolor_render_pass.RenderPass.init_clear();
    const shadowmap_pass = watercolor_render_pass.RenderPass.init_shadowmap(allocator);
    const geo_pass = watercolor_render_pass.RenderPass.init_geometry();
    const edge_detection_pass = watercolor_render_pass.RenderPass.init_edge_detection(allocator);
    const pigment_manipulation_pass = watercolor_render_pass.RenderPass.init_pigment_manipulation(allocator);
    const separable_pass = watercolor_render_pass.RenderPass.init_separable(allocator);
    const bleed_pass = watercolor_render_pass.RenderPass.init_bleed(allocator);
    const edge_manipulation_pass = watercolor_render_pass.RenderPass.init_edge_manipulation(allocator);
    const gaps_overlaps_pass = watercolor_render_pass.RenderPass.init_gaps_overlaps(allocator);
    const pigment_application_pass = watercolor_render_pass.RenderPass.init_pigment_application(allocator);
    const substrate_pass = watercolor_render_pass.RenderPass.init_substrate(allocator);
    const swap_pass = watercolor_render_pass.RenderPass.init_swap(allocator);
    var rp = forward_plus.ForwardPlus(watercolor_render_pass.RenderPass, shader.PainterlyShaderConfig).init();
    rp.addPass(clear_pass);
    rp.addPass(shadowmap_pass);
    rp.addPass(geo_pass);
    rp.addPass(edge_detection_pass);
    rp.addPass(pigment_manipulation_pass);
    rp.addPass(separable_pass);
    rp.addPass(bleed_pass);
    rp.addPass(edge_manipulation_pass);
    rp.addPass(gaps_overlaps_pass);
    rp.addPass(pigment_application_pass);
    rp.addPass(substrate_pass);
    rp.addPass(swap_pass);
    return rp;
}

fn manga_forward_plus(allocator: std.mem.Allocator) forward_plus.ForwardPlus(manga_render_pass.RenderPass, shader.ToonShaderConfig, manga_gbuffer.GBuffer, manga_pbuffer.PBuffer) {
    const clear_pass = manga_render_pass.RenderPass.init_clear();
    const shadowmap_pass = manga_render_pass.RenderPass.init_shadowmap(allocator);
    const geo_pass = manga_render_pass.RenderPass.init_geometry();
    const edge_detection_pass = manga_render_pass.RenderPass.init_edge_detection(allocator);
    //const pigment_manipulation_pass = manga_render_pass.RenderPass.init_pigment_manipulation(allocator);
    //const separable_pass = manga_render_pass.RenderPass.init_separable(allocator);
    //const bleed_pass = manga_render_pass.RenderPass.init_bleed(allocator);
    const edge_manipulation_pass = manga_render_pass.RenderPass.init_edge_manipulation(allocator);
    //const gaps_overlaps_pass = manga_render_pass.RenderPass.init_gaps_overlaps(allocator);
    //const pigment_application_pass = manga_render_pass.RenderPass.init_pigment_application(allocator);
    //const substrate_pass = manga_render_pass.RenderPass.init_substrate(allocator);
    const swap_pass = manga_render_pass.RenderPass.init_swap(allocator);
    var rp = forward_plus.ForwardPlus(
        manga_render_pass.RenderPass,
        shader.ToonShaderConfig,
        manga_gbuffer.GBuffer,
        manga_pbuffer.PBuffer,
    ).init();
    rp.addPass(clear_pass);
    rp.addPass(shadowmap_pass);
    rp.addPass(geo_pass);
    rp.addPass(edge_detection_pass);
    //rp.addPass(pigment_manipulation_pass);
    //rp.addPass(separable_pass);
    //rp.addPass(bleed_pass);
    rp.addPass(edge_manipulation_pass);
    //rp.addPass(gaps_overlaps_pass);
    //rp.addPass(pigment_application_pass);
    //rp.addPass(substrate_pass);
    rp.addPass(swap_pass);
    return rp;
}
