use @import("import.zig");
use @import("math.zig");

const ECS = @import("entity.zig");

const List = @import("std").ArrayList;
const DebugDraw = @import("main.zig").GFX.DebugDraw;

const Blob = struct {
    const MAX_NUM_CONNECTED: u32 = 4;

    position: Vec3,
    velocity: Vec3,

    connected: u32,
    connections: [MAX_NUM_CONNECTED]u32,

    weight: f32,

    pub fn create() Blob {
        return Blob{
            .position = V3(randReal(), randReal(), randReal()),
            .velocity = V3(0, 0, 0),
            .connected = 0,
            .connections = undefined,
            .weight = randPosReal() * 3 + 3,
        };
    }
};

pub const LevelGen = struct {
    const BlobList = List(Blob);
    blobs: BlobList,
    y_scale: f32,

    pub fn create(num_blobs: i32, y_scale: f32) !LevelGen {
        assert(num_blobs > 0);
        var level_gen = LevelGen{
            .blobs = BlobList.init(A),
            .y_scale = y_scale,
        };
        try level_gen.blobs.ensureCapacity(@intCast(usize, num_blobs));
        // Generate
        {
            var i = num_blobs;
            while (i > 0): (i -= 1) {
                try level_gen.blobs.append(Blob.create());
            }
        }
        level_gen.blobs.toSlice()[0].position = V3(0, 0, 0);
        // NOTE: You can connect to the same node multiple times,
        // because why not?
        const blobs = level_gen.blobs.toSlice();
        for (blobs) |*blob, i| {
            var n = (randPosInt() & (Blob.MAX_NUM_CONNECTED - 1)) + 1;
            while (n > 0) {
                var connect_to = @mod(randPosInt(), @intCast(u32, num_blobs));
                n -= 1;
                if (connect_to == i) continue;
                blob.connections[blob.connected] = connect_to;
                blob.connected += 1;
            }
        }
        return level_gen;
    }

    // TODO: This isn't numerically stable, this can be made smarter.
    pub fn step(self: LevelGen) void {
        const delta: f32 = 0.01;
        const blobs = self.blobs.toSlice();
        for (blobs) |blob, i| {
            if (i == 0) continue;
            const p = blob.position;
            var acc = V3(0, 0, 0);
            var n: u32 = 0;
            // TODO(ed): Pulling force from connections, pushing force from
            // ALL other, too tired.
            for (blobs) |other, j| {
                if (i == j) continue;
                const d = other.position.sub(p);
                acc = acc.sub(d.scale(2 * other.weight / d.lengthSq()));
            }
            while (n < blob.connected): (n += 1) {
                const other = blobs[blob.connections[n]];
                const d = other.position.sub(p);
                const l = d.lengthSq();
                if (l == 0.0) continue;
                acc = acc.add(d.scale(other.weight / l));
            }
            blob.velocity = blob.velocity.add(acc.scale(delta / blob.weight));
            blob.position = blob.position.add(blob.velocity.scale(delta));
            blob.velocity = blob.velocity.scale(0.9);
        }
    }

    pub fn generate(self: LevelGen, ecs: *ECS.ECS, drawable: ECS.Drawable) void {
        const blobs = self.blobs.toSlice();
        for (blobs) |blob, i| {
            const p = blob.position.hadamard(V3(2.5, self.y_scale, 2.0));
            const w = blob.weight;
            var a = ecs.create(
            ECS.Transform{
                .position = p,
                .rotation = Quat.identity(),
                .scale = w,
            },
            ECS.Physics.create(V3(w, w, w), false),
            drawable,
            );
            var b = ecs.create(
            ECS.Transform{
                .position = p.add(V3(0, w, 0)),
                .rotation = Quat.identity(),
                .scale = 1.0,
            },
            ECS.SpawnPoint.create());
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

