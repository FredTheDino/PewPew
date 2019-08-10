use @import("import.zig");

use @import("math.zig");
const Phy = @import("collision.zig");
const GFX = @import("graphics.zig");
const Input = @import("input.zig");
const loadMesh = @import("obj_loader.zig").loadMesh;

var window_width: i32 = 800;
var window_height: i32 = 800;
var window_aspect_ratio: f32 = undefined;

pub const ECS = @import("entity.zig");

//    - Entity System (pass 1)
// TODO:
//    - Model loading
//      o Shading
//      o Shadow maps :o
//    - Split screen
//    - Mouse Controls (No?)
//      - Player models
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
    window_aspect_ratio = @intToFloat(f32, window_width) / @intToFloat(f32, window_height);
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
        .program = &program,
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
        .program = &program,
        .mesh = &cone,
    },
    );

    _ = ecs.create(
    ECS.Transform{
        .position = V3(0, -10, 0),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Physics.create(V3(10, 10, 10), false),
    ECS.Drawable{
        .mesh = &cube,
        .program = &program,
    });

    var post_processing_shader = try GFX.Shader.compile("res/post_process.glsl");
    var framebuffer_a = try GFX.Framebuffer.create(&post_processing_shader,
                                                 @intCast(u32, window_width),
                                                 @intCast(u32, @divTrunc(window_height, 2)));

    var framebuffer_b = try GFX.Framebuffer.create(&post_processing_shader,
                                                 @intCast(u32, window_width),
                                                 @intCast(u32, @divTrunc(window_height, 2)));

    _ = ecs.create(
    ECS.Transform{
        .position = V3(-10, -8, 0),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Physics.create(V3(10, 10, 10), false),
    ECS.Drawable{
        .mesh = &cube,
        .program = &program,
    });


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



        var view: Mat4 = undefined;
        const split_screen = false;
        const debug_cam = false;
        const debug_draw = false;

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glClearColor(0.0, 0.1, 0.1, 1.0);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        if (debug_draw) {
            view = player_a.dep().getPlayer().getViewMatrix(player_a.dep());
            glViewport(0, 0,
                    @intCast(c_int, screen_width),
                    @intCast(c_int, screen_height));

            x_rot -= 2 * Input.value(0, Input.Event.LOOK_X) * delta;
            y_rot += 2 * Input.value(0, Input.Event.LOOK_Y) * delta;
            const rot = Mat4.rotation(y_rot, x_rot, 0);

            const vel = V4(4 * Input.value(0, Input.Event.MOVE_X) * delta,
                           0,
                           4 * Input.value(0, Input.Event.MOVE_Y) * delta,
                           0);
            cam_pos = cam_pos.sub(rot.mulVec(vel).toV3());
            view = rot.mulMat(Mat4.translation(cam_pos));


        }

        var i: u2 = 0;
        while (i < 2) : (i += 1) {
            var player = switch(i) {
                0 => player_a,
                else => player_b,
            };
            var framebuffer = switch(i) {
                0 => framebuffer_a,
                else => framebuffer_b,
            };

            framebuffer.bind();
            view = player.dep().getPlayer().getViewMatrix(player.dep());
            glClearColor(0.1, 0.0, 0.1, 1.0);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            program.bind();
            program.update();
            program.sendCamera(projection, view);

            program.setTexture(0);
            texture.bind(0);
            // TODO: Only call draw here.
            ecs.update(delta);

            switch(i) {
                0 => {
                    program.bind();
                    gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
                    gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
                    gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

                    world.draw();
                    gfx_util.draw(program);

                    framebuffer.render_to_screen(window_width,
                            window_height,
                            V2(-1, -1),
                            V2(1, 0));
                },
                else => {
                    framebuffer.render_to_screen(window_width,
                            window_height,
                            V2(-1, 0),
                            V2(1, 1));
                },
            }
        }

        SDL_GL_SwapWindow(window);
    }
}
