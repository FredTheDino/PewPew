use @import("import.zig");

use @import("math.zig");
const Phy = @import("collision.zig");
pub const GFX = @import("graphics.zig");
const Input = @import("input.zig");
pub const ECS = @import("entity.zig");
const loadMesh = @import("obj_loader.zig").loadMesh;
const LevelGen = @import("level.zig").LevelGen;

var window_width: i32 = 1600;
var window_height: i32 = 800;
var window_aspect_ratio: f32 = undefined;

const DEBUG_CAMERA = true;
const DISABLE_SPLITSCREEN = false or DEBUG_CAMERA;
const DEBUG_DRAW = false;

//    - Entity System (pass 1)
// TODO:
//    - Multi sampling
//    - Hit effects
//       - Particles
//       - Sound effects
//    - Better movement
//       - Tweak jump
//       - Double jump?
//       - Dash/Dodge?
//    - Level generation
//       - Moving obstacles
//       - Interconnection, generate a graph and use that?
//          - Will it be interesting?
//       - Verticality?
//          - Movement options for this?
//    - Input activation
//
//    - Sound thread
//    - Asset system? Don't think I will need it...
//
// Maybes:
//    - Hot reloading of assets?
//    - Compile time preparation of assets?
//    - UI?
//    - Level editor?
//    - Online MP.
//

// Globals

var gfx_util: *GFX.DebugDraw = undefined;
var world: *Phy.World = undefined;
var ecs: *ECS.ECS = undefined;

    // Load assets? Somehow into global memory...
var program: GFX.Shader = undefined;
var post_program: GFX.Shader = undefined;

var monkey: GFX.Mesh = undefined;
var cube: GFX.Mesh = undefined;
var cone: GFX.Mesh = undefined;

var projection: Mat4 = undefined;

var texture: GFX.Texture = undefined;

var shadow_map: GFX.Framebuffer = undefined;

fn onResize(x: i32, y: i32) void {
    glViewport(0, 0, x, y);
    window_width = x;
    window_height = y;
    window_aspect_ratio =
            @intToFloat(f32, window_width) /
            @intToFloat(f32, window_height) /
            switch(DISABLE_SPLITSCREEN) { false => 2.0, true => 1.0, };
    projection = Mat4.perspective(60, window_aspect_ratio);
}

fn create_world() void {
    LevelGen.generate(16,
                      ecs,
                      ECS.Drawable{ .mesh = &cube, .texture = &texture, });
}

fn spawn_players() ![switch(DISABLE_SPLITSCREEN) { true => 1, false => 2, }]ECS.EntityID {
    const collision_dim = V3(0.5, 3, 0.5);
    var player_a = ecs.create(
    ECS.Transform{
        .position = V3(0, 0, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Physics.create(collision_dim, true),
    ECS.Player.create(0, 0),
    ECS.Drawable{
        .texture = &texture,
        .mesh = &cone,
    },
    );

    var player_b = ecs.create(
    ECS.Transform{
        .position = V3(0, 0, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.Movable.still(),
    ECS.Physics.create(collision_dim, true),
    ECS.Player.create(1, 1),
    ECS.Drawable{
        .texture = &texture,
        .mesh = &cone,
    },
    );

    var players = switch (DISABLE_SPLITSCREEN) {
        false => [_]ECS.EntityID{ player_a, player_b },
        true => [_]ECS.EntityID{ player_a },
    };

    for (players) |player| {
        var player_comp = player.dep().getPlayer();
        player_comp.framebuffer = try GFX.Framebuffer.create(&post_program,
                @intCast(u32, @divTrunc(window_width, @intCast(i32, players.len))),
                @intCast(u32, window_height));
    }
    return players;
}

fn initalize_open_gl() *SDL_Window {
    assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_AUDIO) == 0);
    const title = c"Hello World";
    var window = SDL_CreateWindow(title,
                                  0,
                                  0,
                                  window_width,
                                  window_height,
                                  SDL_WINDOW_OPENGL) orelse unreachable;

    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_CONTEXT_MAJOR_VERSION), 3);
    _ = SDL_GL_SetAttribute(@intToEnum(SDL_GLattr, SDL_GL_CONTEXT_MINOR_VERSION), 1);
    var context = SDL_GL_CreateContext(window);

    assert(gladLoadGL() != 0);

    onResize(window_width, window_height);

    assert(SDL_GL_SetSwapInterval(1) == 0);

    glEnable(GL_DEPTH_TEST);
    return window;
}

fn debugDraw() void {
    if (!DEBUG_DRAW) return;
    program.bind();
    gfx_util.line(V3(0, 0, 0), V3(0.5, 0, 0), V3(0.5, 0, 0));
    gfx_util.line(V3(0, 0, 0), V3(0, 0.5, 0), V3(0, 0.5, 0));
    gfx_util.line(V3(0, 0, 0), V3(0, 0, 0.5), V3(0, 0, 0.5));

    world.draw();
    gfx_util.draw(program);
}

pub fn main() anyerror!void {
    const window = initalize_open_gl();

    // Initialize sub-systems
    gfx_util = GFX.DebugDraw.init();
    world = Phy.World.init();
    ecs = ECS.ECS.init();

    // Load assets? Somehow into global memory...
    program = try GFX.Shader.compile("res/shader.glsl");
    post_program = try GFX.Shader.compile("res/post_process.glsl");

    monkey = try loadMesh("res/monkey.obj");
    cube = try loadMesh("res/cube.obj");
    cone = try loadMesh("res/player.obj");

    texture = try GFX.Texture.load("res/test.png");

    shadow_map = try GFX.Framebuffer.create(&post_program,
                                                 @intCast(u32, 512 * 1),
                                                 @intCast(u32, 512 * 1));

    _ = ecs.create(
    ECS.Transform{
        .position = V3(0, 0, 0),
        .rotation = Quat.identity(),
        .scale = 1,
    },
    ECS.SpawnPoint.create());

    const players = try spawn_players();
    create_world();

    var light_yaw: f32 = 0.7;
    var light_pitch: f32  = 0.4;

    var last_tick: f32 = 0;
    var delta: f32 = 0;


    while (true) {

        const tick = @intToFloat(f32, SDL_GetTicks()) / 1000.0;
        delta = tick - last_tick;
        last_tick = tick;

        Input.update();
        if (Input.down(0, Input.Event.QUIT))
            break;

        world.update(delta);
        ecs.update(delta);

        const sun_proj = Mat4.orthographic(20, 20, -8, 8);
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
            debugCamera(delta);
        } else {
            for (players) |player_id, i| {
                if (!player_id.isValid()) continue;
                var player_comp = player_id.dep().getPlayer();
                var framebuffer = player_comp.framebuffer;
                framebuffer.bind();

                const view = player_comp.getViewMatrix();

                program.bind();
                program.update();
                program.sendCamera(projection, view);
                ecs.draw(program);

                debugDraw();

                if (DISABLE_SPLITSCREEN) {
                    framebuffer.render_to_screen(window_width, window_height, V2(-1, -1), V2(1, 1));
                    break;
                } else {
                    const min = V2(-1 + @intToFloat(f32, i), -1);
                    const max = V2(0+ @intToFloat(f32, i), 1 );
                    framebuffer.render_to_screen(window_width, window_height, min, max);
                }
            }
        }
        SDL_GL_SwapWindow(window);
    }
}

var cam_pos : Vec3 = V3(-8, 0, 0);
var x_rot : f32 = math.pi / 2.0;
var y_rot : f32 = 0;
fn debugCamera(delta: f32) void {
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
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0,
            @intCast(c_int, window_width),
            @intCast(c_int, window_height));

    glClearColor(0.2, 0.0, 0.1, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, shadow_map.texture);

    ecs.draw(program);


    debugDraw();

    // Render shadow map onto in lower left corner
    glClear(GL_DEPTH_BUFFER_BIT);
    shadow_map.render_to_screen(window_width, window_height,
            V2(-1.0, -1.0),
            V2(-1.0 + 0.5, -1.0 + 0.5 * window_aspect_ratio));
}
