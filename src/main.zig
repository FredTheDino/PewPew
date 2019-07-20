use @import("import.zig");

use @import("math.zig");
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;
const Vertex = @import("mesh.zig").Vertex;
const DebugDraw = @import("mesh.zig").DebugDraw;
const Input = @import("input.zig").Input;

var window_width: i32 = 800;
var window_height: i32 = 800;
var window_aspect_ratio: f32 = undefined;

pub const ECS = @import("entities.zig");

// TODO:
//    - Debug drawing lines and points
//    - Entity System
//    - Compile time model loading
//    - Asset system?
//    - Sound thread
//    - Begin on actual game
//
// Maybes:
//    - Hot reloading of assets?
//    - Compile time preparation of assets?
//    - UI?
//    - Level editor?
//

const Keys = enum {
    NONE,
    QUIT,
    JUMP,
    LEFT,
    RIGHT,

    /// This is the mapping function that
    /// takes an SDL input and returns the
    /// corresponding enum.
    pub fn map(pressed_key: c_int) @This() {
        return switch(pressed_key) {
            SDLK_a => Keys.LEFT,
            SDLK_d => Keys.RIGHT,
            SDLK_LEFT => Keys.LEFT,
            SDLK_RIGHT => Keys.RIGHT,
            SDLK_SPACE => Keys.JUMP,

            SDLK_ESCAPE => Keys.QUIT,
            else => Keys.NONE,
        };
    }
};

var projection: Mat4 = undefined;
fn onResize(x: i32, y: i32) void {
    glViewport(0, 0, x, y);
    window_width = x;
    window_height = y;
    window_aspect_ratio = @intToFloat(f32, window_width) / @intToFloat(f32, window_height);
    projection = Mat4.perspective(120, window_aspect_ratio);
}

pub fn main() anyerror!void {
    var status = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
    assert(status == 0);



    var title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0, 0,
                                  window_width, window_height,
                                  SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

    var input = Input.InputHandler(Keys).create(onResize);

    var context = SDL_GL_CreateContext(window);

    assert(gladLoadGL() != 0);

    onResize(window_width, window_height);

    glEnable(GL_DEPTH_TEST);


    const program = try Shader.compile("res/shader.glsl");
    program.bind();

    const mesh = Mesh.createSimple([]Vertex {
        Vertex.p(-0.5,  0.5, 0),
        Vertex.p( 0.0, -0.5, 0),
        Vertex.p( 0.5,  0.5, 0),
    });

    const cube = Mesh.createIndexed([]Vertex {
        Vertex { .x = -0.5, .y = -0.5, .z = -0.5, },
        Vertex { .x = -0.5, .y = -0.5, .z =  0.5, },
        Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },
        Vertex { .x = -0.5, .y =  0.5, .z = -0.5, },

        Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Vertex { .x =  0.5, .y = -0.5, .z =  0.5, },
        Vertex { .x =  0.5, .y =  0.5, .z =  0.5, },
        Vertex { .x =  0.5, .y =  0.5, .z = -0.5, },
    }, []c_int {
        // Left
        0, 1, 2,    0, 2, 3,
        // Right
        4, 5, 6,    4, 6, 7,
        // Front
        0, 4, 7,    0, 7, 3,
        // Back
        5, 1, 2,    5, 2, 6,
        // Top
        3, 7, 6,    3, 6, 2,
        // Bottom
        0, 5, 1,    0, 5, 4,
        

    });

    var entity = ECS.Entity.create();

    entity.add(ECS.Transform {
        .position = V3(0, 0, 0),
        .rotation = V3(1, 1, 1),
        .scale = 1.0,
    });

    entity.add(ECS.Drawable {
        .mesh = &cube,
        .program = &program,
    });

    var line_util = DebugDraw.init();

    glClearColor(0.1, 0.0, 0.1, 1.0);
    var last_tick: f32 = 0;
    var delta: f32 = 0;
    var x: f32 = 0;
    while (true) {
        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;
        delta = tick - last_tick;
        last_tick = tick;

        input.update();
        if (input.isDown(Keys.QUIT))
            break;

        const speed = 1 * delta;
        if (input.isDown(Keys.LEFT))
            x -= speed;
        if (input.isDown(Keys.RIGHT))
            x += speed;

        const s = math.sin(tick);
        const t = math.cos(tick);

        const rotation = Mat4.rotation(x, 0, 0);
        const translation = Mat4.translation(V3(0, 0, -3));
        const scaling = Mat4.identity();
        const view = translation.mulMat(rotation.mulMat(scaling));

        // const camera = translation.mulMat(rotation.mulMat(perspective));

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        program.update();
        program.sendCamera(projection, view);
        
        line_util.drawLine(V3(0, 0, 0), V3(10, 0, 0), V3(1, 0, 0));
        line_util.drawLine(V3(0, 0, 0), V3(0, 10, 0), V3(0, 1, 0));
        
        entity.update(delta);
//         program.sendModel(Mat4.translation(V3(0, 0, -1)));
//         cube.draw();
//
//         program.sendModel(Mat4.translation(V3(1, 1, -1))
//                   .mulMat(Mat4.rotation(0, s, t))
//                   .mulMat(Mat4.scale(s, 1, 2))
//         );
//         cube.draw();
//
//         program.sendModel(Mat4.scale(2, 2, 2));
//         cube.draw();
        line_util.draw(program);

        SDL_GL_SwapWindow(window);
        SDL_Delay(10);
    }
}
