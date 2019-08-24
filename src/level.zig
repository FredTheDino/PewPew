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

        const grid_dim: f32 = 4.0;
        const size_f = @intToFloat(f32, size);
        var x = -size_f + 0.5 * grid_dim;
        while (x < size_f): (x += grid_dim) {
            var y = -size_f + 0.5 * grid_dim;
            while (y < size_f): (y += grid_dim) {
                if (math.fabs(x) + math.fabs(y) >= size_f + 0.2 * grid_dim)
                    continue;
                if (randReal() < 0.0)
                    continue;
                const p = V3(x, 2, y);
                _ = ecs.create(
                ECS.Transform{
                    .position = p,
                    .rotation = Quat.identity(),
                    .scale = grid_dim / 2.0,
                },
                ECS.Physics.create(V3(grid_dim, grid_dim, grid_dim), false),
                drawable);
            }
        }
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

