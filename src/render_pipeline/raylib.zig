const target = @import("builtin").target;

pub usingnamespace @cImport({
    @cDefine("SUPPORT_HIGH_DPI", "1");
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

pub fn RenderTextureDPI() c_int {
    if (target.os.tag == .macos) {
        return 2;
    } else {
        return 1;
    }
}
