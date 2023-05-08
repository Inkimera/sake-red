const std = @import("std");
const raylib = @import("../raylib.zig");
const rlgl = @cImport(@cInclude("rlgl.h"));

// Edge Frame Buffer
pub const EBuffer = struct {
    id: c_uint,
    width: c_int,
    height: c_int,
    edge: raylib.Texture,

    pub fn init() EBuffer {
        const width = raylib.GetRenderWidth();
        const height = raylib.GetRenderHeight();
        var ebuf = std.mem.zeroes(EBuffer);
        ebuf.id = rlgl.rlLoadFramebuffer(width, height);
        ebuf.width = width;
        ebuf.height = height;

        if (ebuf.id > 0) {
            rlgl.rlEnableFramebuffer(ebuf.id);

            // Create color texture: style
            ebuf.edge.id = rlgl.rlLoadTexture(null, width, height, raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8, 1);
            ebuf.edge.width = width;
            ebuf.edge.height = height;
            ebuf.edge.format = raylib.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
            ebuf.edge.mipmaps = 1;

            // Attach color textures to FBO
            rlgl.rlFramebufferAttach(ebuf.id, ebuf.edge.id, rlgl.RL_ATTACHMENT_COLOR_CHANNEL0, rlgl.RL_ATTACHMENT_TEXTURE2D, 0);

            // Activate required color draw buffers
            rlgl.rlActiveDrawBuffers(1);

            // Check if fbo is complete with attachments (valid)
            if (rlgl.rlFramebufferComplete(ebuf.id)) {
                std.debug.print("MRT loaded\n", .{});
            }
            rlgl.rlDisableFramebuffer();
        } else {
            std.debug.print("MRT failed to load\n", .{});
        }

        return ebuf;
    }

    pub fn deinit(self: *EBuffer) void {
        if (self.id > 0) {
            // Delete color texture attachments
            rlgl.rlUnloadTexture(self.edge.id);

            // NOTE: Depth texture is automatically queried
            // and deleted before deleting framebuffer
            rlgl.rlUnloadFramebuffer(self.id);
            std.debug.print("MRT unloaded\n", .{});
        }
    }

    pub fn beginBufferMode(self: *const EBuffer) void {
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

    pub fn endBufferMode(_: *const EBuffer) void {
        rlgl.rlDrawRenderBatchActive(); // Update and draw internal render batch
        rlgl.rlDisableFramebuffer(); // Disable render target (fbo)

        // Set viewport to default framebuffer size
        //raylib.SetupViewport(raylib.CORE.Window.render.width, raylib.CORE.Window.render.height);

        // Reset current fbo to screen size
        //raylib.CORE.Window.currentFbo.width = raylib.CORE.Window.render.width;
        //raylib.CORE.Window.currentFbo.height = raylib.CORE.Window.render.height;
    }
};
