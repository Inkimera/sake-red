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
const render_pass = @import("render_pipeline/render_pass.zig");
const model = @import("render_pipeline/model.zig");

pub fn main() !void {
    const screenWidth = raylib.GetRenderWidth();
    const screenHeight = raylib.GetRenderHeight();

    raylib.SetConfigFlags(raylib.FLAG_MSAA_4X_HINT | raylib.FLAG_VSYNC_HINT);
    raylib.InitWindow(screenWidth, screenHeight, "SakaRed");
    raylib.SetWindowState(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.SetExitKey(raylib.KEY_NULL);
    defer raylib.CloseWindow();

    // Define the camera to look into our 3d world
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
    const data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/basic.json", 512);
    var stream = std.json.TokenStream.init(data);
    var config = try std.json.parse(shader.PainterlyShaderConfig, &stream, .{ .allocator = allocator });
    allocator.free(data);

    // Load painterly lighting shader
    var painterly_shader = shader.Shader.init("painterly", "src/shaders/painterly.vs", "src/shaders/painterly.fs", &shader.PainterlyShaderConfig.uniforms(), allocator);
    defer painterly_shader.deinit();

    var plane = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshPlane(100.0, 100.0, 3, 3)), &painterly_shader);
    var monkey = model.Model.init(raylib.LoadModel("assets/models/monkey.glb"), &painterly_shader);
    monkey.translate(raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 });
    var cube = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshCube(2.0, 2.0, 2.0)), &painterly_shader);
    cube.translate(raylib.Vector3{ .x = 4.0, .y = 1.0, .z = 0.0 });
    var sphere = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(1.0, 32.0, 32.0)), &painterly_shader);
    sphere.translate(raylib.Vector3{ .x = -4.0, .y = 1.0, .z = 0.0 });

    // Assign painterly shader to model
    plane.model.materials[0].shader = painterly_shader.shader;
    plane.model.materials[0].maps[raylib.MATERIAL_MAP_DIFFUSE].texture = raylib.LoadTexture("assets/textures/bronze/rusted/albedo.png");
    monkey.model.materials[0].shader = painterly_shader.shader;
    cube.model.materials[0].shader = painterly_shader.shader;
    sphere.model.materials[0].shader = painterly_shader.shader;
    //plane.shader_config = config;
    plane.shader_config.specular_transparency = 0.3;
    monkey.shader_config = config;
    cube.shader_config = config;
    sphere.shader_config = config;

    // Lights
    var l1 = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.5, 32.0, 32.0)), &painterly_shader);
    l1.translate(raylib.Vector3{ .x = 0.0, .y = 7.0, .z = 3.0 });
    l1.model.materials[0].shader = painterly_shader.shader;
    l1.shader_config.emission = [3]f32{ 0.8, 0.4, 0.0 };
    l1.shader_config.dark_edges = 0.0;
    l1.shader_config.disable_lighting = 1;

    var l2 = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.5, 32.0, 32.0)), &painterly_shader);
    l2.translate(raylib.Vector3{ .x = 8.0, .y = 12.0, .z = 3.0 });
    l2.model.materials[0].shader = painterly_shader.shader;
    l2.shader_config.emission = [3]f32{ 0.8, 0.8, 0.8 };
    l2.shader_config.dark_edges = 0.0;
    l2.shader_config.disable_lighting = 1;

    var l3 = model.Model.init(raylib.LoadModelFromMesh(raylib.GenMeshSphere(0.5, 32.0, 32.0)), &painterly_shader);
    l3.translate(raylib.Vector3{ .x = -8.0, .y = 12.0, .z = 3.0 });
    l3.model.materials[0].shader = painterly_shader.shader;
    l3.shader_config.emission = [3]f32{ 0.8, 0.8, 0.8 };
    l3.shader_config.dark_edges = 0.0;
    l3.shader_config.disable_lighting = 1;

    var models = [_]*model.Model{ &plane, &monkey, &cube, &sphere, &l1, &l2, &l3 };

    // Render Passes
    const clear_pass = render_pass.RenderPass.init_clear();
    //const shadow_map_pass = render_pass.RenderPass.init_shadow_map();
    const geo_pass = render_pass.RenderPass.init_geometry();
    const edge_detection_pass = render_pass.RenderPass.init_edge_detection(allocator);
    const pigment_manipulation_pass = render_pass.RenderPass.init_pigment_manipulation(allocator);
    const separable_pass = render_pass.RenderPass.init_separable(allocator);
    const bleed_pass = render_pass.RenderPass.init_bleed(allocator);
    const edge_manipulation_pass = render_pass.RenderPass.init_edge_manipulation(allocator);
    const gaps_overlaps_pass = render_pass.RenderPass.init_gaps_overlaps(allocator);
    const swap_pass = render_pass.RenderPass.init_swap(allocator);
    const pigment_application_pass = render_pass.RenderPass.init_pigment_application(allocator);
    const substrate_pass = render_pass.RenderPass.init_substrate(allocator);
    var rp = forward_plus.ForwardPlus.init();
    rp.addPass(clear_pass);
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

    // Create lights
    var lights = [_]Light{
        //CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = -4.0, .y = 10.0, .z = -4.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
        //CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 4.0, .y = 10.0, .z = 6.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
        //CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = -4.0, .y = 10.0, .z = 6.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
        //CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 4.0, .y = 10.0, .z = -4.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
        CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 0.0, .y = 7.0, .z = 3.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.ORANGE, painterly_shader.shader),
        CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = 8.0, .y = 12.0, .z = 3.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
        CreateLight(@enumToInt(LightType.LIGHT_POINT), raylib.Vector3{ .x = -8.0, .y = 12.0, .z = 3.0 }, raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 }, raylib.WHITE, painterly_shader.shader),
    };
    lights[0].attenuation = 1.0;
    lights[0].intensity = 2.0;
    lights[1].attenuation = 0.5;
    lights[1].intensity = 1.2;
    lights[2].attenuation = 0.5;
    lights[2].intensity = 1.2;

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
                const new_data = try std.fs.cwd().readFileAlloc(allocator, "assets/materials/basic.json", 512);
                defer allocator.free(new_data);
                stream = std.json.TokenStream.init(new_data);
                if (std.json.parse(shader.PainterlyShaderConfig, &stream, .{ .allocator = allocator })) |new_config| {
                    monkey.shader_config = new_config;
                    //models[1].shader_config = config;
                    std.debug.print("Shader Config Updated\n", .{});
                } else |_| {
                    std.debug.print("Shader Config Invalid\n", .{});
                }
            }
        }

        var cameraPos = [3]f32{ camera.position.x, camera.position.y, camera.position.z };
        painterly_shader.setUniform("camera", &cameraPos, raylib.SHADER_UNIFORM_VEC3);

        for (lights) |l| {
            UpdateLightValues(painterly_shader.shader, l);
        }

        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        // Render
        rp.render(camera, &models);
        // Debug
        raylib.DrawFPS(10.0, 10.0);
        rp.resize();
    }
}
