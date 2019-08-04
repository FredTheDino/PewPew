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
//    - Better way of doing input
//    - Model loading
//      o Shading
//      o Shadow maps :o
//    - Split screen
//    - Mouse Controls
//    - Player Movement (Multi player?)
//    - Collision (box vs line and box vs box) (AABB or boxes?)
//    - Controller support
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

    var context = SDL_GL_CreateContext(window);
    assert(gladLoadGL() != 0);

    onResize(window_width, window_height);

    assert(SDL_GL_SetSwapInterval(1) == 0);
    glEnable(GL_DEPTH_TEST);

    var gfx_util = GFX.DebugDraw.init();

    const program = try GFX.Shader.compile("res/shader.glsl");
    program.bind();

    var monkey = try loadMesh("res/monkey.obj");
    var cube = try loadMesh("res/cube.obj");

    var ecs = ECS.ECS.init();

    var texture = try GFX.Texture.load("res/test.png");

    _ = ecs.create(
    ECS.Transform{
        .position = V3(0, -10, 0),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Drawable{
        .mesh = &cube,
        .program = &program,
    });

    _ = ecs.create(
    ECS.Transform{
        .position = V3(0, -4, 0),
        .rotation = Quat.identity(),
        .scale = 2,
    },
    ECS.Drawable{
        .mesh = &monkey,
        .program = &program,
    });

    var player = ecs.create(
    ECS.Transform{
        .position = V3(0, 0, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Player.create(0),
    );
    var world = Phy.World.init();
    var body_a = world.create(V3(1, 1, 0.5), true);
    body_a.dep().position = V3(0, -2, -5);

    var body_b = world.create(V3(1, 0.5, 1.0), true);
    body_b.dep().position = V3(0, 1, -5);
    body_b.dep().velocity = V3(0.2, -1, 0.2);

    const entity_a = ecs.create(
    ECS.Transform{
        .position = V3(-4, -1, -5),
        .rotation = Quat.identity(),
        .scale = 0.5,
    }, ECS.Movable{
        .linear = V3(2, -0.3, 0),
        .rotational = V3(0, 0, 0),
        .damping = 1,
    }, ECS.Physics.create(V3(1, 1, 1), true)
    , ECS.Drawable{
        .mesh = &cube,
        .program = &program,
    });

    glClearColor(0.1, 0.0, 0.1, 1.0);
    var last_tick: f32 = 0;
    var delta: f32 = 0;
    while (true) {
        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;
        delta = tick - last_tick;
        last_tick = tick;

        Input.update();
        if (Input.down(0, Input.Event.QUIT))
            break;

        program.setTexture(0);
        texture.bind(0);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        program.update();
        const view = player.dep()
                           .getPlayer()
                           .getViewMatrix(player.dep());
        program.sendCamera(projection, view);

        world.update(delta);
        world.draw();

        gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
        gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
        gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

        ecs.update(delta);
        gfx_util.draw(program);

        SDL_GL_SwapWindow(window);
    }
}
