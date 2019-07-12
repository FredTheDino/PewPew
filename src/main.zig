use @import("import.zig");

use @import("math.zig");
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;

const WINDOW_WIDTH: i32 = 800;
const WINDOW_HEIGHT: i32 = 800;

pub fn main() anyerror!void {
    var status = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
    assert(status == 0);

    var title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0, 0, 
                                  WINDOW_WIDTH, WINDOW_HEIGHT,
                                  SDL_WINDOW_OPENGL);

    var context = SDL_GL_CreateContext(window);

    assert(gladLoadGL() != 0);

    const program = try Shader.compile("res/shader.glsl");
    program.bind();

    const mesh = Mesh.create([]Mesh.Vertex {
        Mesh.Vertex { .x = -0.5, .y =  0.5, .z = 0, },
        Mesh.Vertex { .x =  0.0, .y = -0.5, .z = 0, },
        Mesh.Vertex { .x =  0.5, .y =  0.5, .z = 0, },
    });

    var running: bool = true;
    glClearColor(1.0, 1.0, 0.0, 1.0);
    while (running) {
        var event: SDL_Event = undefined;
        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;

        const s = math.sin(tick);
        const t = math.cos(tick);
        const perspective = Mat4.perspective(80 + s * 20);
        const rotation = Mat4.rotation(0, s, 0);
        const translation = Mat4.translation(V3(0, 0, -2));
        // const camera = translation.mulMat(rotation.mulMat(perspective));
        const camera = translation.mulMat(rotation.mulMat(perspective));
        camera.dump();

        while (SDL_PollEvent(&event) != 0) {
            if (event.type == SDL_WINDOWEVENT) {
                if (event.window.event == SDL_WINDOWEVENT_CLOSE) {
                    running = false;
                }
            } else {
                // std.debug.warn("Type: {}\n", event.type);
            }
        }

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        program.update(camera);
        program.draw_at(V3( 0,  0,  1));
        mesh.draw();

        program.draw_at(V3(-1,  0,  1));
        mesh.draw();

        program.draw_at(V3( 1,  0,  1));
        mesh.draw();

        program.draw_at(V3( 0,  1,  1));
        mesh.draw();

        program.draw_at(V3( 0, -1,  1));
        mesh.draw();

        program.draw_at(V3(-1,  0,  0));
        mesh.draw();

        program.draw_at(V3( 1,  0,  0));
        mesh.draw();

        program.draw_at(V3( 0,  1,  0));
        mesh.draw();

        program.draw_at(V3( 0, -1,  0));
        mesh.draw();

        SDL_GL_SwapWindow(window);
        SDL_Delay(10);
    }
}
