/// All C headers, needed like everywhere.
pub use @cImport({
    @cInclude("SDL2/SDL.h");

    @cInclude("glad/glad.h");

    @cDefine("STBI_ONLY_PNG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});

/// Standard library with assers, if I want to
/// roll my own I can.
pub const std = @import("std");
pub const assert = std.debug.assert;

// TODO(Ed): Replace this with something like: 
//    var arena = std.heap.DirectAllocator.init();
//    defer arena.deinit();
//    const allocator = &arena.allocator;
pub const a = std.heap.c_allocator;

