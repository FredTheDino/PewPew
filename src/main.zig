use @import("import.zig");

use @import("math.zig");
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;
const Input = @import("input.zig").Input;

const WINDOW_WIDTH: i32 = 800;
const WINDOW_HEIGHT: i32 = 800;

// TODO: Fix view matrix.


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
            SDLK_SPACE => Keys.JUMP,

            SDLK_ESCAPE => Keys.QUIT,
            else => Keys.NONE,
        };
    }
};

pub fn main() anyerror!void {
    var status = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
    assert(status == 0);

    var n = Input.InputHandler(Keys){ .states = undefined, };

    var title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0, 0, 
                                  WINDOW_WIDTH, WINDOW_HEIGHT,
                                  SDL_WINDOW_OPENGL);

    var context = SDL_GL_CreateContext(window);

    assert(gladLoadGL() != 0);
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

    const aspect_ratio = @intToFloat(f32, WINDOW_WIDTH) / @intToFloat(f32, WINDOW_HEIGHT);

    const projection = Mat4.perspective(120, aspect_ratio);
    projection.dump();

    glClearColor(0.1, 0.0, 0.1, 1.0);
    var x: f32 = 0;
    while (true) {
        n.update();
        if (n.isDown(Keys.QUIT))
            break;

        const speed = 0.01;
        if (n.isDown(Keys.LEFT))
            x -= speed;
        if (n.isDown(Keys.RIGHT))
            x += speed;
        
        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;

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
