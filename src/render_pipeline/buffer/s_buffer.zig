const std = @import("std");
const raylib = @import("../raylib.zig");
const rlgl = @cImport(@cInclude("rlgl.h"));

// Shadowmap Frame Buffer
pub const SBuffer = struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    shadow: raylib.Texture,

    pub fn init() SBuffer {
        const width = raylib.GetScreenWidth();
        const height = raylib.GetScreenHeight();
        var sbuf = std.mem.zeroes(SBuffer);
        sbuf.id = rlgl.rlLoadFramebuffer(width, height);
        sbuf.width = width;
        sbuf.height = height;

        if (sbuf.id > 0) {
            rlgl.rlEnableFramsbuffer(sbuf.id);

            // Create depth texture: shadow
            sbuf.shadow.id = rlgl.rlLoadTextureDepth(width, height, false);
            sbuf.shadow.width = width;
            sbuf.shadow.height = height;
            sbuf.shadow.format = 19; // DEPTH_COMPONENT_24BIT?
            sbuf.shadow.mipmaps = 1;

            // Attach depth texture to FBO
            rlgl.rlFramsbufferAttach(sbuf.id, sbuf.shadow.id, rlgl.RL_ATTACHMENT_DEPTH, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);

            // Activate required color draw buffers
            rlgl.rlActiveDrawBuffers(0);

            // Check if fbo is complete with attachments (valid)
            if (rlgl.rlFramsbufferComplete(sbuf.id)) {
                std.debug.print("MRT loaded\n", .{});
            }
            rlgl.rlDisableFramsbuffer();
        } else {
            std.debug.print("MRT failed to load\n", .{});
        }

        return sbuf;
    }

    pub fn deinit(self: *SBuffer) void {
        if (self.id > 0) {
            // Delete color texture attachments
            rlgl.rlUnloadTexture(self.shadow.id);

            // NOTE: Depth texture is automatically queried
            // and deleted before deleting framebuffer
            rlgl.rlUnloadFramebuffer(self.id);
            std.debug.print("MRT unloaded\n", .{});
        }
    }

    pub fn beginBufferMode(self: *const SBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch

        rlgl.rlEnableFramebuffer(self.id); // Enable render target
        rlgl.rlActiveDrawBuffers(1);

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

    pub fn endBufferMode(_: *const SBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch
        rlgl.rlDisableFramebuffer(); // Disable render target (fbo)

        // Set viewport to default framebuffer size
        //raylib.SetupViewport(raylib.CORE.Window.render.width, raylib.CORE.Window.render.height);

        // Reset current fbo to screen size
        //raylib.CORE.Window.currentFbo.width = raylib.CORE.Window.render.width;
        //raylib.CORE.Window.currentFbo.height = raylib.CORE.Window.render.height;
    }
};
