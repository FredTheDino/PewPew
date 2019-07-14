use @import("import.zig");

use @import("math.zig");
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;
const Input = @import("input.zig").Input;

var WINDOW_WIDTH: i32 = 800;
var WINDOW_HEIGHT: i32 = 800;
var WINDOW_ASPECT_RATIO: f32 = undefined;

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
    WINDOW_WIDTH = x;
    WINDOW_HEIGHT = y;
    WINDOW_ASPECT_RATIO = @intToFloat(f32, WINDOW_WIDTH) / @intToFloat(f32, WINDOW_HEIGHT);
    std.debug.warn("AR: {}\n", WINDOW_ASPECT_RATIO);
    projection = Mat4.perspective(120, WINDOW_ASPECT_RATIO);
}

pub fn main() anyerror!void {
    var status = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
    assert(status == 0);


    var title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0, 0, 
                                  WINDOW_WIDTH, WINDOW_HEIGHT,
                                  SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

    var input = Input.InputHandler(Keys).create(onResize);

    var context = SDL_GL_CreateContext(window);

    assert(gladLoadGL() != 0);

    onResize(WINDOW_WIDTH, WINDOW_HEIGHT);

    glEnable(GL_DEPTH_TEST);


    const program = try Shader.compile("res/shader.glsl");
    program.bind();

    const mesh = Mesh.create([]Mesh.Vertex {
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = 0, },
        Mesh.Vertex { .x =  0.0, .y = -0.5, .z = 0, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = 0, },
    });

    const cube = Mesh.create([]Mesh.Vertex {
        // Left Face
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },

        Mesh.Vertex { .x = -0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = -0.5, },

        // Right Face
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z =  0.5, },

        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = -0.5, },

        // top face
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = -0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },

        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = -0.5, },

        // bottom face
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z =  0.5, },

        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z = -0.5, },

        // front face
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },

        Mesh.Vertex { .x =  0.5, .y = -0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z =  0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z =  0.5, },

        // back face
        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = -0.5, },

        Mesh.Vertex { .x =  0.5, .y = -0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = -0.5, },
        Mesh.Vertex { .x = -0.5, .y = -0.5, .z = -0.5, },
    });


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

        program.sendModel(Mat4.translation(V3(0, 0, -1)));
        cube.draw();

        program.sendModel(Mat4.translation(V3(1, 1, -1))
                  .mulMat(Mat4.rotation(0, s, t))
                  .mulMat(Mat4.scale(s, 1, 2))
        );
        cube.draw();

        program.sendModel(Mat4.scale(2, 2, 2));
        cube.draw();

        SDL_GL_SwapWindow(window);
        SDL_Delay(10);
    }
}
