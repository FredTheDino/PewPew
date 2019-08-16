use @import("import.zig");

use @import("math.zig");
const Phy = @import("collision.zig");
const GFX = @import("graphics.zig");
const Input = @import("input.zig");
const loadMesh = @import("obj_loader.zig").loadMesh;

var window_width: i32 = 800;
var window_height: i32 = 800;
var window_aspect_ratio: f32 = undefined;

const DISABLE_SPLITSCREEN = true;
const DEBUG_CAMERA = true;
const DEBUG_DRAW = false;


pub const ECS = @import("entity.zig");

//    - Entity System (pass 1)
// TODO:
//    - Multisampling
//    - aspect ratio
//    - Refactor code and make neat and easy to work with
//
//    - Sound thread
//    - Asset system?
//
// Maybes:
//    - Hot reloading of assets?
//    - Compile time preparation of assets?
//    - UI?
//    - Level editor?
//    - Online MP.
//

var projection: Mat4 = undefined;
fn onResize(x: i32, y: i32) void {
    glViewport(0, 0, x, y);
    window_width = x;
    window_height = y;
    window_aspect_ratio =
            @intToFloat(f32, window_width) /
            @intToFloat(f32, window_height) /
            switch(DISABLE_SPLITSCREEN) { false => 0.5, true => 1.0, };
    projection = Mat4.perspective(60, window_aspect_ratio);
}

pub fn main() anyerror!void {
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_AUDIO) == 0);

    const title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0,
                                  0,
                                  window_width,
                                  window_height,
                                  SDL_WINDOW_OPENGL);

    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_CONTEXT_MAJOR_VERSION), 3);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_CONTEXT_MINOR_VERSION), 1);
    var context = SDL_GL_CreateContext(window);
    assert(gladLoadGL() != 0);


    onResize(window_width, window_height);

    assert(SDL_GL_SetSwapInterval(1) == 0);
    glEnable(GL_DEPTH_TEST);

    var gfx_util = GFX.DebugDraw.init();

    var world = Phy.World.init();

    const program = try GFX.Shader.compile("res/shader.glsl");

    // var monkey = try loadMesh("res/monkey.obj");
    var cube = try loadMesh("res/cube.obj");
    var cone = try loadMesh("res/player.obj");

    var ecs = ECS.ECS.init();

    var texture = try GFX.Texture.load("res/test.png");

    var player_a = ecs.create(
    ECS.Transform{
        .position = V3(0, 3, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Physics.create(V3(0.5, 3, 0.5), true),
    ECS.Player.create(0),
    ECS.Drawable{
        .texture = &texture,
        .mesh = &cone,
    },
    );

    var player_b = ecs.create(
    ECS.Transform{
        .position = V3(-3, 4, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Physics.create(V3(0.5, 3, 0.5), true),
    ECS.Player.create(1),
    ECS.Drawable{
        .texture = &texture,
        .mesh = &cone,
    },
    );

    var post_processing_shader = try GFX.Shader.compile("res/post_process.glsl");
    const players = switch (DISABLE_SPLITSCREEN) {
        false => [_]ECS.EntityID{ player_a, player_b },
        true => [_]ECS.EntityID{ player_a },
    };

    for (players) |player| {
        var player_comp = player.dep().getPlayer();
        player_comp.framebuffer = try GFX.Framebuffer.create(&post_processing_shader,
                @intCast(u32, window_width),
                @intCast(u32, @divTrunc(window_height, @intCast(i32, players.len))));
    }

    _ = ecs.create(
    ECS.Transform{
        .position = V3(0, -10, 0),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Physics.create(V3(10, 10, 10), false),
    ECS.Drawable{
        .mesh = &cube,
        .texture = &texture,
    });


    var shadow_map = try GFX.Framebuffer.create(&post_processing_shader,
                                                 @intCast(u32, 512 * 3),
                                                 @intCast(u32, 512 * 3));

    _ = ecs.create(
    ECS.Transform{
        .position = V3(-15, -5, 2),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Physics.create(V3(10, 10, 10), false),
    ECS.Drawable{
        .mesh = &cube,
        .texture = &texture,
    });


    // TODO: Something strange about light dir.
    // var light_dir = V3(0, 2, 1).normalized();
    var light_yaw: f32 = 0.7;
    var light_pitch: f32  = 0.4;

    var last_tick: f32 = 0;
    var delta: f32 = 0;

    var cam_pos : Vec3 = V3(0, 0, 0);
    var x_rot : f32= 0;
    var y_rot : f32= 0;
    while (true) {

        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;
        delta = tick - last_tick;
        last_tick = tick;

        Input.update();
        if (Input.down(0, Input.Event.QUIT))
            break;

        world.update(delta);
        ecs.update(delta);

        const sun_proj = Mat4.orthographic(20, 20, -5, 5);
        const sun_view = Mat4.rotation(light_yaw, light_pitch, 0);

        // Draw shadow map
        program.bind();
        program.update();
        program.sendSun(sun_proj, sun_view, 2);
        program.sendCamera(sun_proj, sun_view);
        {
            shadow_map.bind();
            glClearColor(1.0, 1.0, 1.0, 1.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            program.shadowMap(true);
            ecs.draw(program);
            program.shadowMap(false);

            glActiveTexture(GL_TEXTURE2);
            glBindTexture(GL_TEXTURE_2D, shadow_map.texture);
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glClearColor(0.0, 0.1, 0.1, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        if (DEBUG_CAMERA) {
            x_rot -= 2 * Input.value(0, Input.Event.LOOK_X) * delta;
            y_rot += 2 * Input.value(0, Input.Event.LOOK_Y) * delta;
            const rot = Mat4.rotation(y_rot, x_rot, 0);

            const vel = V4(4 * Input.value(0, Input.Event.MOVE_X) * delta,
                           0,
                           4 * Input.value(0, Input.Event.MOVE_Y) * delta,
                           0);
            cam_pos = cam_pos.sub(rot.mulVec(vel).toV3());
            const view = rot.mulMat(Mat4.translation(cam_pos));
            program.sendCamera(projection, view);

            // Draw to screen
            if (true) {
                glBindFramebuffer(GL_FRAMEBUFFER, 0);
                glViewport(0, 0,
                        @intCast(c_int, window_width),
                        @intCast(c_int, window_height));

                glClearColor(0.2, 0.0, 0.1, 1.0);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

                glActiveTexture(GL_TEXTURE2);
                glBindTexture(GL_TEXTURE_2D, shadow_map.texture);

                ecs.draw(program);

                if (DEBUG_DRAW) {
                    program.bind();
                    // gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
                    // gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
                    // gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

                    world.draw();
                    gfx_util.draw(program);
                }

                glClear(GL_DEPTH_BUFFER_BIT);
                shadow_map.render_to_screen(window_width, window_height,
                                            V2(-1, -1),
                                            V2(-0.5, -0.5));
            }
        } else {
            // Normal render path
            for (players) |player_id, i| {
                var player_comp = player_id.dep().getPlayer();
                var framebuffer = player_comp.framebuffer;
                framebuffer.bind();

                const view = player_comp.getViewMatrix();

                program.bind();
                program.update();
                program.sendCamera(projection, view);
                ecs.draw(program);

                if (DEBUG_DRAW and i == 0) {
                    program.bind();
                    // gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
                    // gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
                    // gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

                    world.draw();
                    gfx_util.draw(program);
                }

                // TODO: Loft to function? Should this be stored on the player?
                var min: Vec2 = undefined;
                var max: Vec2 = undefined;
                switch (players.len) {
                    1 => {
                        min = V2(-1, -1);
                        max = V2(1, 1);
                    },
                      2 => {
                          min = V2(-1, -1 + @intToFloat(f32, i));
                          max = V2(1, 0 + @intToFloat(f32, i));
                      },
                      else => unreachable,
                }
                framebuffer.render_to_screen(window_width, window_height, min, max);
            }
        }
        SDL_GL_SwapWindow(window);
    }
}
