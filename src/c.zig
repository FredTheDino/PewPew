use @cImport({
    @cInclude("SDL2/SDL.h");

    @cInclude("glad/glad.h");

    @cDefine("STBI_ONLY_PNG", "");
    @cDefine("STBI_NO_STDIO", "");
    @cInclude("stb_image.h");
});

const std = @import("std");
