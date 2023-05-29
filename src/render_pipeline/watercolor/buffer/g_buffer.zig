const std = @import("std");
const raylib = @import("../../raylib.zig");
const rlgl = @cImport(@cInclude("rlgl.h"));

// Geometry Frame Buffer
pub const GBuffer = struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    color: raylib.Texture,
    normal: raylib.Texture,
    control: raylib.Texture,
    depth: raylib.Texture,

    pub fn init() GBuffer {
        const width = raylib.GetRenderWidth();
        const height = raylib.GetRenderHeight();
        var gbuf = std.mem.zeroes(GBuffer);
        gbuf.id = rlgl.rlLoadFramebuffer(width, height);
        gbuf.width = width;
        gbuf.height = height;

        if (gbuf.id > 0) {
            rlgl.rlEnableFramebuffer(gbuf.id);

            // Create color texture: color
            gbuf.color.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            gbuf.color.width = width;
            gbuf.color.height = height;
            gbuf.color.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            gbuf.color.mipmaps = 1;
            raylib.SetTextureFilter(gbuf.color, raylib.TEXTURE_FILTER_TRILINEAR);

            // Create color texture: normal
            gbuf.normal.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            gbuf.normal.width = width;
            gbuf.normal.height = height;
            gbuf.normal.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            gbuf.normal.mipmaps = 1;
            raylib.SetTextureFilter(gbuf.color, raylib.TEXTURE_FILTER_TRILINEAR);

            // Create color texture: control
            gbuf.control.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            gbuf.control.width = width;
            gbuf.control.height = height;
            gbuf.control.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            gbuf.control.mipmaps = 1;
            raylib.SetTextureFilter(gbuf.color, raylib.TEXTURE_FILTER_TRILINEAR);

            //// Create color texture: edge
            //gbuf.edge.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            //gbuf.edge.width = width;
            //gbuf.edge.height = height;
            //gbuf.edge.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            //gbuf.edge.mipmaps = 1;

            // Create depth texture
            gbuf.depth.id = rlgl.rlLoadTextureDepth(width, height, false);
            gbuf.depth.width = width;
            gbuf.depth.height = height;
            gbuf.depth.format = 19; // DEPTH_COMPONENT_24BIT?
            gbuf.depth.mipmaps = 1;
            raylib.SetTextureFilter(gbuf.color, raylib.TEXTURE_FILTER_TRILINEAR);

            // Attach color textures and depth textures to FBO
            rlgl.rlFramebufferAttach(gbuf.id, gbuf.color.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL0, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);
            rlgl.rlFramebufferAttach(gbuf.id, gbuf.normal.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL1, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);
            rlgl.rlFramebufferAttach(gbuf.id, gbuf.control.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL2, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);
            rlgl.rlFramebufferAttach(gbuf.id, gbuf.depth.id, rlgl.RL_ATTACHMENT_DEPTH, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);

            // Activate required color draw buffers
            rlgl.rlActiveDrawBuffers(3);

            // Check if fbo is complete with attachments (valid)
            if (rlgl.rlFramebufferComplete(gbuf.id)) {
                std.debug.print("MRT loaded\n", .{});
            }
            rlgl.rlDisableFramebuffer();
        } else {
            std.debug.print("MRT failed to load\n", .{});
        }

        return gbuf;
    }

    pub fn deinit(self: *GBuffer) void {
        if (self.id > 0) {
            // Delete color texture attachments
            rlgl.rlUnloadTexture(self.color.id);
            rlgl.rlUnloadTexture(self.normal.id);
            rlgl.rlUnloadTexture(self.control.id);

            // NOTE: Depth texture is automatically queried
            // and deleted before deleting framebuffer
            rlgl.rlUnloadFramebuffer(self.id);
            std.debug.print("MRT unloaded\n", .{});
        }
    }

    pub fn beginBufferMode(self: *const GBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch

        rlgl.rlEnableFramebuffer(self.id); // Enable render target
        rlgl.rlActiveDrawBuffers(3);

        // Set viewport and RLGL internal framebuffer size
        rlgl.rlViewport(0, 0, self.width, self.height);
        rlgl.rlSetFramebufferWidth(self.width);
        rlgl.rlSetFramebufferHeight(self.height);

        rlgl.rlMatrixMode(rlgl.RL_PROJECTION); // Switch to projection matrix
        rlgl.rlLoadIdentity(); // Reset current matrix (projection)

        // Set orthographic projection to current framebuffer size
        // NOTE: Configured top-left corner as (0, 0)
        rlgl.rlOrtho(0, @intToFloat(f32, self.width), @intToFloat(f32, self.height), 0, 0.0, 1.0);

        rlgl.rlMatrixMode(rlgl.RL_MODELVIEW); // Switch back to modelview matrix
        rlgl.rlLoadIdentity(); // Reset current matrix (modelview)

        //rlScalef(0.0f, -1.0f, 0.0f);  // Flip Y-drawing (?)

        // Setup current width/height for proper aspect ratio
        // calculation when using BeginMode3D()
        //raylib.CORE.Window.currentFbo.width = self.color.width;
        //raylib.CORE.Window.currentFbo.height = self.color.height;
    }

    pub fn endBufferMode(_: *const GBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch
        rlgl.rlDisableFramebuffer(); // Disable render target (fbo)

        // Set viewport to default framebuffer size
        //raylib.SetupViewport(raylib.CORE.Window.render.width, raylib.CORE.Window.render.height);

        // Reset current fbo to screen size
        //raylib.CORE.Window.currentFbo.width = raylib.CORE.Window.render.width;
        //raylib.CORE.Window.currentFbo.height = raylib.CORE.Window.render.height;
    }
};
