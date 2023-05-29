const std = @import("std");
const raylib = @import("../../raylib.zig");
const rlgl = @cImport(@cInclude("rlgl.h"));

// Post Process Frame Buffer
pub const PBuffer = struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    style: raylib.Texture,
    bleed: raylib.Texture,
    darkened_edge: raylib.Texture,

    pub fn init() PBuffer {
        const width = raylib.GetRenderWidth();
        const height = raylib.GetRenderHeight();
        var pbuf = std.mem.zeroes(PBuffer);
        pbuf.id = rlgl.rlLoadFramebuffer(width, height);
        pbuf.width = width;
        pbuf.height = height;

        if (pbuf.id > 0) {
            rlgl.rlEnableFramebuffer(pbuf.id);

            // Create color texture: style
            pbuf.style.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            pbuf.style.width = width;
            pbuf.style.height = height;
            pbuf.style.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            pbuf.style.mipmaps = 1;
            raylib.SetTextureFilter(pbuf.style, raylib.TEXTURE_FILTER_TRILINEAR);

            // Create color texture: bleed
            pbuf.bleed.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            pbuf.bleed.width = width;
            pbuf.bleed.height = height;
            pbuf.bleed.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            pbuf.bleed.mipmaps = 1;
            raylib.SetTextureFilter(pbuf.bleed, raylib.TEXTURE_FILTER_TRILINEAR);

            // Create color texture: darkened_edge
            pbuf.darkened_edge.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            pbuf.darkened_edge.width = width;
            pbuf.darkened_edge.height = height;
            pbuf.darkened_edge.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            pbuf.darkened_edge.mipmaps = 1;
            raylib.SetTextureFilter(pbuf.darkened_edge, raylib.TEXTURE_FILTER_TRILINEAR);

            // Attach color textures to FBO
            rlgl.rlFramebufferAttach(pbuf.id, pbuf.style.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL0, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);
            rlgl.rlFramebufferAttach(pbuf.id, pbuf.bleed.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL1, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);
            rlgl.rlFramebufferAttach(pbuf.id, pbuf.darkened_edge.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL2, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);

            // Activate required color draw buffers
            rlgl.rlActiveDrawBuffers(3);

            // Check if fbo is complete with attachments (valid)
            if (rlgl.rlFramebufferComplete(pbuf.id)) {
                std.debug.print("MRT loaded\n", .{});
            }
            rlgl.rlDisableFramebuffer();
        } else {
            std.debug.print("MRT failed to load\n", .{});
        }

        return pbuf;
    }

    pub fn deinit(self: *PBuffer) void {
        if (self.id > 0) {
            // Delete color texture attachments
            rlgl.rlUnloadTexture(self.style.id);
            rlgl.rlUnloadTexture(self.bleed.id);
            rlgl.rlUnloadTexture(self.darkened_edge.id);

            // NOTE: Depth texture is automatically queried
            // and deleted before deleting framebuffer
            rlgl.rlUnloadFramebuffer(self.id);
            std.debug.print("MRT unloaded\n", .{});
        }
    }

    pub fn beginBufferMode(self: *const PBuffer) void {
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

    pub fn endBufferMode(_: *const PBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch
        rlgl.rlDisableFramebuffer(); // Disable render target (fbo)

        // Set viewport to default framebuffer size
        //raylib.SetupViewport(raylib.CORE.Window.render.width, raylib.CORE.Window.render.height);

        // Reset current fbo to screen size
        //raylib.CORE.Window.currentFbo.width = raylib.CORE.Window.render.width;
        //raylib.CORE.Window.currentFbo.height = raylib.CORE.Window.render.height;
    }
};
