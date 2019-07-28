use @import("import.zig");

use @import("math.zig");
const GFX = @import("graphics.zig");
const Input = @import("input.zig").Input;

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

const Keys = enum {
    NONE,
    QUIT,
    JUMP,
    LEFT,
    RIGHT,
    UP,
    DOWN,

    P_PITCH,
    N_PITCH,
    P_YAW,
    N_YAW,

    /// This is the mapping function that
    /// takes an SDL input and returns the
    /// corresponding enum.
    pub fn map(pressed_key: c_int) @This() {
        return switch (pressed_key) {
            SDLK_a => Keys.LEFT,
            SDLK_d => Keys.RIGHT,
            SDLK_w => Keys.UP,
            SDLK_s => Keys.DOWN,

            SDLK_e => Keys.P_PITCH,
            SDLK_q => Keys.N_PITCH,

            SDLK_1 => Keys.P_YAW,
            SDLK_2 => Keys.N_YAW,

            SDLK_LEFT => Keys.LEFT,
            SDLK_RIGHT => Keys.RIGHT,
            SDLK_SPACE => Keys.JUMP,

            SDLK_ESCAPE => Keys.QUIT,
            else => Keys.NONE,
        };
    }
};
pub const InputHandler = Input.InputHandler(Keys);

var projection: Mat4 = undefined;
fn onResize(x: i32, y: i32) void {
    glViewport(0, 0, x, y);
    window_width = x;
    window_height = y;
    window_aspect_ratio = @intToFloat(f32, window_width) / @intToFloat(f32, window_height);
    projection = Mat4.perspective(60, window_aspect_ratio);
}

pub fn main() anyerror!void {
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) == 0);


    const title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0,
                                  0,
                                  window_width,
                                  window_height,
                                  SDL_WINDOW_OPENGL);
    var input = InputHandler.init(onResize);

    var context = SDL_GL_CreateContext(window);
    assert(gladLoadGL() != 0);

    onResize(window_width, window_height);

    assert(SDL_GL_SetSwapInterval(1) == 0);
    glEnable(GL_DEPTH_TEST);

    var gfx_util = GFX.DebugDraw.init();

    const program = try GFX.Shader.compile("res/shader.glsl");
    program.bind();

    const mesh = GFX.Mesh.createSimple([]GFX.Vertex{
        GFX.Vertex.pt(-0.5,  0.5, 0,     -0.5,  0.5),
        GFX.Vertex.pt( 0.0, -0.5, 0,      0.0, -0.5),
        GFX.Vertex.pt( 0.5,  0.5, 0,      0.5,  0.5),
    });

    const cube = GFX.Mesh.createIndexed([]GFX.Vertex{
        GFX.Vertex.pt(-0.5, -0.5, -0.5,      0.5,  0.5),
        GFX.Vertex.pt(-0.5, -0.5,  0.5,      0.5,  0.5),
        GFX.Vertex.pt(-0.5,  0.5,  0.5,      0,  1),
        GFX.Vertex.pt(-0.5,  0.5, -0.5,      0,  0),
        GFX.Vertex.pt( 0.5, -0.5, -0.5,      0.5,  0.5),
        GFX.Vertex.pt( 0.5, -0.5,  0.5,      0.5,  0.5),
        GFX.Vertex.pt( 0.5,  0.5,  0.5,      1,  1),
        GFX.Vertex.pt( 0.5,  0.5, -0.5,      1,  0),
    }, []c_int{
        // Left
        0, 1, 2,     0, 2, 3,
        // Right
        4, 5, 6,     4, 6, 7,
        // Front
        0, 4, 7,     0, 7, 3,
        // Back
        5, 1, 2,     5, 2, 6,
        // Top
        3, 7, 6,     3, 6, 2,
        // Bottom
        0, 5, 1,     0, 5, 4,
    });

    var ecs = ECS.ECS.init();

    var texture = try GFX.Texture.load("res/test.png");

    var floor = ecs.create(
    ECS.Transform{
        .position = V3(0, -5, 0),
        .rotation = Quat.identity(),
        .scale = 5,
    },
    ECS.Drawable{
        .mesh = &cube,
        .program = &program,
    });

    var player = ecs.create(
    ECS.Transform{
        .position = V3(0, 0, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Player.create(&input),
    );

    glClearColor(0.1, 0.0, 0.1, 1.0);
    var last_tick: f32 = 0;
    var delta: f32 = 0;
    var x: f32 = 0;
    var y: f32 = 0;
    while (true) {
        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;
        delta = tick - last_tick;
        last_tick = tick;


        input.update();
        if (input.isDown(Keys.QUIT))
            break;

        const speed = 1 * delta;
        if (input.isDown(Keys.LEFT))
            y -= speed;
        if (input.isDown(Keys.RIGHT))
            y += speed;
        if (input.isDown(Keys.UP))
            x += speed;
        if (input.isDown(Keys.DOWN))
            x -= speed;

        const s = math.sin(tick);
        const t = math.cos(tick);

        if (false) {
            const rotation = Mat4.rotation(x, y, 0);
            const translation = Mat4.translation(V3(0, 0, -3));
            const scaling = Mat4.identity();
            const view = translation.mulMat(rotation.mulMat(scaling));
        }

        program.setTexture(0);
        texture.bind(0);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        program.update();
        const view = player.deNoNull().getPlayer().getViewMatrix(player.deNoNull());
        program.sendCamera(projection, view);

        gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
        gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
        gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

        ecs.update(delta);
        gfx_util.draw(program);

        SDL_GL_SwapWindow(window);
    }
}
