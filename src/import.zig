/// All C headers, needed like everywhere.
pub use @cImport({
    @cInclude("SDL2/SDL.h");

    @cInclude("glad/glad.h");

    @cDefine("STBI_NO_STDIO", "");
    @cDefine("STBI_ONLY_PNG", "");
    @cInclude("stb_image.h");
});
pub const Controller: type = SDL_GameController;
// Better Controller mappings
pub const SDLA_LEFTX = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_LEFTX);
pub const SDLA_LEFTY = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_LEFTY);
pub const SDLA_RIGHTX = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_RIGHTX);
pub const SDLA_RIGHTY = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_RIGHTY);
pub const SDLA_TRIGGERL = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_TRIGGERLEFT);
pub const SDLA_TRIGGERR = @intToEnum(SDL_GameControllerAxis, SDL_CONTROLLER_AXIS_TRIGGERRIGHT);

pub const NUM_PLAYER_ID_BITS = 2;
pub const PlayerId = u2;

/// Standard library with assers, if I want to
/// roll my own I can.
pub const std = @import("std");
pub const assert = std.debug.assert;
pub const log = std.debug.warn;

pub use @import("math.zig");

// TODO(Ed): Replace this with something like:
//    var arena = std.heap.DirectAllocator.init();
//    defer arena.deinit();
//    const allocator = &arena.allocator;
pub const A = std.heap.c_allocator;

