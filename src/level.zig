use @import("import.zig");
use @import("math.zig");

const ECS = @import("entity.zig");

const List = @import("std").ArrayList;
const DebugDraw = @import("main.zig").GFX.DebugDraw;

pub const LevelGen = struct {

    fn rotSnap(snap: f32) Quat {
        return AA(V3(0, 1, 0), (snap * 2 + 1) * math.pi / 4.0);
    }

    pub fn generate(size: i32, ecs: *ECS.ECS, drawable: ECS.Drawable) void {
        assert(size > 0);
        const dim = @intToFloat(real, size);
        _ = ecs.create(
        ECS.Transform{
            .position = V3(0, -dim, 0),
            .rotation = Quat.identity(),
            .scale = dim,
        },
        ECS.Physics.create(V3(2 * dim, 2 * dim, 2 * dim), false),
        drawable);


        const offset = 1.0;
        const player_height = 2.0;
        _ = ecs.create(
        ECS.Transform{
            .position = V3(-dim + offset, player_height, -dim + offset),
            .rotation = rotSnap(0),
            .scale = 1.0,
        },
        ECS.SpawnPoint.create());
        _ = ecs.create(
        ECS.Transform{
            .position = V3(-dim + offset, player_height,  dim - offset),
            .rotation = rotSnap(1),
            .scale = 1.0,
        },
        ECS.SpawnPoint.create());
        _ = ecs.create(
        ECS.Transform{
            .position = V3( dim - offset, player_height,  dim - offset),
            .rotation = rotSnap(2),
            .scale = 1.0,
        },
        ECS.SpawnPoint.create());
        _ = ecs.create(
        ECS.Transform{
            .position = V3( dim - offset, player_height, -dim + offset),
            .rotation = rotSnap(3),
            .scale = 1.0,
        },
        ECS.SpawnPoint.create());

        // var x = -size;
        // while (x < size): (x += 1) {
        //     var y = -size;
        //     while (y < size): (y += 1) {
        //         const p = V3(@intToFloat(f32, x), 0, @intToFloat(f32, y));
        //         const w = 1.0;
        //         _ = ecs.create(
        //         ECS.Transform{
        //             .position = p,
        //             .rotation = Quat.identity(),
        //             .scale = w,
        //         },
        //         ECS.Physics.create(V3(2.0 * w, 2.0 * w, 2.0 * w), false),
        //         drawable);
        //     }
        // }
    }

    pub fn draw(self: LevelGen) void {
        DebugDraw.gfx_util.line(V3(0, 0, 10), V3(10, 0, 0), V3(1, 0, 1));
        const blobs = self.blobs.toSlice();
        for (blobs) |blob| {
            const p = blob.position.hadamard(V3(1.0, self.y_scale, 1.0));
            DebugDraw.gfx_util.point(p, V3(1.0, 0.4, 0.2));
            var n: u32 = 0;
            while (n < blob.connected): (n += 1) {
                const other = blobs[blob.connections[n]];
                const q = other.position.hadamard(V3(1.0, self.y_scale, 1.0));
                DebugDraw.gfx_util.line(p, q, V3(0.4, 1.0, 0.3));
            }
        }
    }
};

