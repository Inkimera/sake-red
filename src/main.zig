const std = @import("std");
const raylib = @import("render_pipeline/raylib.zig");
//const toml = @import("vendor/zig-toml/src/main.zig");

const light = @import("light.zig");
const MAX_LIGHTS = light.MAX_LIGHTS;
const Light = light.Light;
const LightType = light.LightType;
const CreateLight = light.CreateLight;
const UpdateLightValues = light.UpdateLightValues;

const shader = @import("render_pipeline/shader.zig");
const forward_plus = @import("render_pipeline/forward_plus.zig");
const watercolor_render_pass = @import("render_pipeline/watercolor/render_pass.zig");
const manga_render_pass = @import("render_pipeline/manga/render_pass.zig");
const model = @import("render_pipeline/model.zig");

pub fn main() !void {
    const screenWidth = raylib.GetRenderWidth();
    const screenHeight = raylib.GetRenderHeight();

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_HIGHDPI | raylib.FLAG_MSAA_4X_HINT);
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

    @setEvalBranchQuota(2000); // WTF zig
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/painterly.json", 512);
    //const data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/toon.json", 512);
    var stream = std.json.TokenStream.init(data);
    var config = try std.json.parse(shader.PainterlyShaderConfig, &stream, .{ .allocator = allocator });
    //var config = try std.json.parse(shader.ToonShaderConfig, &stream, .{ .allocator = allocator });
    allocator.free(data);

    // Load painterly lighting shader
    var model_shader = shader.Shader.init(
        "painterly",
        "src/shaders/painterly.vs",
        "src/shaders/painterly.fs",
        &shader.PainterlyShaderConfig.uniforms(),
        allocator,
    );
    defer model_shader.deinit();

    //var model_shader = shader.Shader.init(
    //    "toon",
    //    "src/shaders/toon.vs",
    //    "src/shaders/toon.fs",
    //    &shader.ToonShaderConfig.uniforms(),
    //    allocator,
    //);
    //defer model_shader.deinit();

    var plane = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshPlane(100.0, 100.0, 3, 3)), &model_shader);
    var monkey = model.Model.init(raylib.LoadModel("assets/models/robot_ball.obj"), &model_shader);
    monkey.translate(raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 });
    var cube = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshCube(2.0, 2.0, 2.0)), &model_shader);
    cube.translate(raylib.Vector3{ .x = 4.0, .y = 1.0, .z = 0.0 });
    var sphere = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(1.0, 32.0, 32.0)), &model_shader);
    sphere.translate(raylib.Vector3{ .x = -4.0, .y = 1.0, .z = 0.0 });

    monkey.shader_config = config;
    cube.shader_config = config;
    sphere.shader_config = config;

    plane.shader_config.albedo = [3]f32{ 0.3, 0.0, 0.0 };
    plane.shader_config.emission = [3]f32{ 0.2, 0.2, 0.2 };
    //plane.shader_config.specular_intensity = 0.2;
    //plane.shader_config.specular_transparency = 0.6;
    //plane.shader_config.uv_wrap_x = 20.0;
    //plane.shader_config.uv_wrap_y = 20.0;

    //cube.shader_config.specular_intensity = 0.4;

    //sphere.shader_config.uv_wrap_x = 4.0;
    //sphere.shader_config.uv_wrap_y = 4.0;

    //const noise = raylib.LoadTexture("assets/textures/noise/simplex_512.png");
    //plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/tile/stone/albedo.png");
    //plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/tile/stone/specular.png");
    //plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = noise;

    //monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/models/MFS_Body.png");
    //monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/gold/painted/specular.png");
    //monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/MFS_Body_Control.png");
    //monkey.model.materials[1].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/MFS_Body_Control.png");
    //monkey.model.materials[2].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/MFS_Body_Control.png");
    //monkey.model.materials[3].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/MFS_Body_Control.png");
    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/models/robot_ball_albedo.png");
    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_SPECULAR].texture = raylib.LoadTexture("assets/models/robot_ball_specular.png");
    monkey.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/models/robot_ball_control.png");

    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/bronze/rusted/albedo.png");
    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/bronze/rusted/specular.png");
    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = noise;
    //cube.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = raylib.LoadTexture("assets/textures/control_1.png");

    //sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/tile/ornate/albedo.png");
    //sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 1].texture = raylib.LoadTexture("assets/textures/tile/ornate/specular.png");
    //sphere.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE + 3].texture = noise;

    // Lights
    var l2 = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.1, 16.0, 16.0)), &model_shader);
    l2.translate(raylib.Vector3{ .x = 0.0, .y = 2.0, .z = 6.0 });
    //l2.model.materials[0].shader = painterly_shader.shader;
    l2.shader_config.emission = [3]f32{ 1.0, 0.6, 0.0 };
    //l2.shader_config.dark_edges = 0.0;
    l2.shader_config.disable_lighting = 1;

    //var l3 = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.5, 32.0, 32.0)), &model_shader);
    //l3.translate(raylib.Vector3{ .x = 0.0, .y = 2.0, .z = -4.0 });
    ////l3.model.materials[0].shader = painterly_shader.shader;
    //l3.shader_config.emission = [3]f32{ 0.1, 0.1, 0.1 };
    ////l3.shader_config.dark_edges = 0.0;
    //l3.shader_config.disable_lighting = 1;

    var models = [_]*model.Model{ &plane, &monkey, &cube, &sphere, &l2 };

    // Render Passes
    var rp = watercolor_forward_plus(allocator);
    //var rp = manga_forward_plus(allocator);

    var dl = CreateLight(@enumToInt(LightType.LIGHT_DIRECTIONAL), raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.Vector3{ .x = 1.0, .y = -1.0, .z = 0.0 }, raylib.WHITE, model_shader.shader);
    var pl1 = CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 0.0, .y = 2.0, .z = 6.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.ORANGE, model_shader.shader);
    //var pl2 = CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 0.0, .y = 2.0, .z = -4.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, model_shader.shader);
    // Create lights
    var lights = [_]*Light{
        &dl,
        &pl1,
        //&pl2,
    };
    lights[0].attenuation = 1.0;
    lights[0].intensity = 0.1;
    lights[1].attenuation = 1.0;
    lights[1].intensity = 2.0;
    //lights[1].attenuation = 1.0;
    //lights[1].intensity = 6.0;

    raylib.SetTargetFPS(60);
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
                std.debug.print("Reloading Shader Config...\n", .{});
                const new_data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/painterly.json", 512);
                //const new_data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/toon.json", 512);
                defer allocator.free(new_data);
                stream = std.json.TokenStream.init(new_data);
                if (std.json.parse(shader.PainterlyShaderConfig, &stream, .{ .allocator = allocator })) |new_config| {
                    monkey.shader_config = new_config;
                    cube.shader_config = new_config;
                    sphere.shader_config = new_config;
                    //models[1].shader_config = config;
                    std.debug.print("Shader Config Updated\n", .{});
                } else |_| {
                    std.debug.print("Shader Config Invalid\n", .{});
                }
            }
        }

        monkey.translate(raylib.Vector3{ .x = -0.001, .y = 0.0, .z = 0.001 });
        if (monkey.transform.z > 5.0) {
            monkey.transform = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }

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

fn watercolor_forward_plus(allocator: std.mem.Allocator) forward_plus.ForwardPlus(watercolor_render_pass.RenderPass) {
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
    var rp = forward_plus.ForwardPlus(watercolor_render_pass.RenderPass).init();
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

fn manga_forward_plus(allocator: std.mem.Allocator) forward_plus.ForwardPlus(manga_render_pass.RenderPass) {
    const clear_pass = manga_render_pass.RenderPass.init_clear();
    //const shadowmap_pass = manga_render_pass.RenderPass.init_shadowmap(allocator);
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
    var rp = forward_plus.ForwardPlus(manga_render_pass.RenderPass).init();
    rp.addPass(clear_pass);
    //rp.addPass(shadowmap_pass);
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
