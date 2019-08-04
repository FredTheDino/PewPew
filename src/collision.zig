//
// Planes?
// Only AABB? Maybe? Maybe not?
// BOX vs BOX with some simple impulses, ties into the entity system.
// BOX vs LINE
// How hard would it be to make a simple SAT tests?

use @import("import.zig");

const ECS = @import("entity.zig");

const DebugDraw = @import("graphics.zig").DebugDraw;
pub var global_world: World = undefined;
const List = @import("std").ArrayList;
// TODO: This is a naïve implementation,
// it's really not as fast as it can be.
pub const BodyID = struct {
    pos: i32,
    gen: u32,

    pub fn isAlive(self: BodyID) bool {
        return self.pos >= 0;
    }

    pub fn de(self: BodyID) ?*Body {
        var e: *Body = &global_world.bodies.toSlice()[@intCast(usize, self.pos)];
        if (e.id.gen != self.gen or e.id.pos != self.pos) return null;
        return e;
    }

    pub fn dep(self: BodyID) *Body {
        return self.de() orelse unreachable;
    }
};

pub const Body = struct {
    id: BodyID,
    // Stored as w/2, h/2, d/2
    dimension: Vec3,

    entity: ?ECS.EntityID,
    // TODO: Collision volumes
    // TODO: Who's colliding with what?
    position: Vec3,
    velocity: Vec3,
    acceleation: Vec3,

    moveable: bool,
    overlapping: bool,

    fn create(dimension: Vec3, moveable: bool) Body {
        return Body{
            .id = BodyID{ .pos = 0, .gen = 0 },
            .dimension = dimension,

            .position = V3(0, 0, 0),
            .velocity =  V3(0, 0, 0),
            .acceleation = V3(0, 0, 0),
            .entity = null,

            .moveable = moveable,
            .overlapping = false,
        };
    }

    pub fn overlaps(a: *Body, b: *Body) Collision {
        const no_collison = Collision{
            .normal = V3(0, 0, 0),
            .depth = 0,
            .a = a.id,
            .b = b.id,
        };
        var collision = no_collison;

        const distance = a.position.sub(b.position);
        const coverage = a.dimension.add(b.dimension).scale(0.5);
        const directions = []Vec3{
            V3(1, 0, 0),
            V3(0, 1, 0),
            V3(0, 0, 1),
        };

        const line = DebugDraw.gfx_util.line;
        for (directions) |d| {
            const axis_distance = distance.dot(d);
            const overlap = coverage.dot(d) - math.fabs(distance.dot(d));
            if (overlap < 0) { return no_collison; }
            if (overlap > collision.depth and
                collision.normal.lengthSq() != 0) { continue; }
            collision.depth = overlap;
            const dir = sign(axis_distance);
            collision.normal = d.abs().scale(dir);
        }
        return collision;
    }

    fn update(self: *Body, delta: f32) void {
        if (self.entity) |id| {
            const entity: *ECS.Entity = id.dep();
            if (entity.has(ECS.ComponentType.movable)) {
                self.velocity = entity.getMoveable().linear;
            }
            if (entity.has(ECS.ComponentType.transform)) {
                self.position = entity.getTransform().position;
            }
        }
        self.velocity = self.velocity.add(self.acceleation.scale(delta));
        self.position = self.position.add(self.velocity.scale(delta));
        self.acceleation = V3(0, 0, 0);
        self.overlapping = false;
    }

    fn tryCopyBack(self: Body) void {
        if (self.entity) |id| {
            const entity: *ECS.Entity = id.dep();
            if (entity.has(ECS.ComponentType.movable))
                entity.getMoveable().linear = self.velocity;
            if (entity.has(ECS.ComponentType.transform))
                entity.getTransform().position = self.position;
        }
    }

    pub fn draw(self: Body) void {
        const point = DebugDraw.gfx_util.point;
        const line = DebugDraw.gfx_util.line;
        const color = switch(self.overlapping) {
            true => V3(0.5, 0.1, 0.8),
            false => V3(0.8, 0.5, 0.1),
        };

        const p = self.position;
        const d = self.dimension;
        line(p.add(d.hadamard(V3(-0.5, -0.5, -0.5))),
             p.add(d.hadamard(V3( 0.5, -0.5, -0.5))),
             color);
        line(p.add(d.hadamard(V3(-0.5, -0.5, -0.5))),
             p.add(d.hadamard(V3(-0.5,  0.5, -0.5))),
             color);
        line(p.add(d.hadamard(V3(-0.5, -0.5, -0.5))),
             p.add(d.hadamard(V3(-0.5, -0.5,  0.5))),
             color);

        line(p.add(d.hadamard(V3( 0.5, -0.5, -0.5))),
             p.add(d.hadamard(V3( 0.5,  0.5, -0.5))),
             color);
        line(p.add(d.hadamard(V3( 0.5, -0.5, -0.5))),
             p.add(d.hadamard(V3( 0.5, -0.5,  0.5))),
             color);

        line(p.add(d.hadamard(V3(-0.5,  0.5, -0.5))),
             p.add(d.hadamard(V3(-0.5,  0.5,  0.5))),
             color);
        line(p.add(d.hadamard(V3(-0.5,  0.5, -0.5))),
             p.add(d.hadamard(V3( 0.5,  0.5, -0.5))),
             color);

        line(p.add(d.hadamard(V3( 0.5,  0.5, -0.5))),
             p.add(d.hadamard(V3( 0.5,  0.5,  0.5))),
             color);

        line(p.add(d.hadamard(V3( 0.5,  0.5,  0.5))),
             p.add(d.hadamard(V3(-0.5,  0.5,  0.5))),
             color);
        line(p.add(d.hadamard(V3( 0.5,  0.5,  0.5))),
             p.add(d.hadamard(V3( 0.5, -0.5,  0.5))),
             color);

        line(p.add(d.hadamard(V3(-0.5, -0.5,  0.5))),
             p.add(d.hadamard(V3( 0.5, -0.5,  0.5))),
             color);
        line(p.add(d.hadamard(V3(-0.5, -0.5,  0.5))),
             p.add(d.hadamard(V3(-0.5,  0.5,  0.5))),
             color);
    }
};

// Where to store these?
pub const Collision = struct {
    const BOUNCE = 0;
    const SKIN = 0.01;
    normal: Vec3,
    depth: f32,
    a: BodyID,
    b: BodyID,

    fn solve(self: *Collision) void {
        var a = self.a.dep();
        var b = self.b.dep();
        const total_velocity = a.velocity.add(b.velocity);
        if (total_velocity.dot(a.position.sub(b.position)) < 0) {
            return;
        }
        a.overlapping = true;
        b.overlapping = true;
        const move_a = @intToFloat(f32, @boolToInt(a.moveable));
        const move_b = @intToFloat(f32, @boolToInt(b.moveable));
        const split = move_a + move_b;
        if (split == 0) {
            return;
        }
        const total_delta = math.min((self.depth + SKIN) / split, 0.0);
        a.position = a.position.add(self.normal.scale(total_delta * move_a));
        b.position = b.position.sub(self.normal.scale(total_delta * move_b));

        if (self.depth < SKIN) { return; }
        const delta_vel = (1 + BOUNCE) * total_velocity.dot(self.normal) / split;
        a.velocity = a.velocity.add(self.normal.scale(delta_vel * move_a));
        b.velocity = b.velocity.sub(self.normal.scale(delta_vel * move_b));
    }
};

pub const World = struct {
    const BodyList = List(Body);

    next_free: i32,
    bodies: BodyList,

    pub fn init() *World {
        global_world = World{
            .bodies = BodyList.init(A),
            .next_free = 0,
        };
        return &global_world;
    }

    fn genId(self: *World) ?BodyID {
        var id = BodyID{ .pos = 0, .gen = 0, };
        if (self.next_free < 0) {
            const i = @intCast(usize, -(1 + self.next_free));
            id = self.bodies.at(i).id;
            self.next_free = id.pos;
            id.pos = @intCast(i32, i);
        } else {
            id = BodyID{
                .pos = self.next_free,
                .gen = 0,
            };
            // TODO: Is this needed?
            _ = self.bodies.addOne()
            catch |err| switch(err) {
                error.OutOfMemory => return null,
            };
            self.next_free += 1;
        }
        return id;
    }

    pub fn create(self: *World, dimension: Vec3, moveable: bool) BodyID {
        var body = Body.create(dimension, moveable);
        var id = self.genId() orelse unreachable;
        body.id = id;
        self.bodies.set(@intCast(usize, id.pos), body);
        return id;
    }

    pub fn remove(self: *World, args: ...) void {
        comptime var i = 0;
        inline while(i < args.len) : (i += 1) {
            const id: BodyID = args[i];
            const b: *Body = id.de() orelse continue;
            const curr = self.next_free;
            self.next_free = -(1 + b.id.pos);
            b.id.pos = curr;
            b.id.gen += 1;
        }
    }

    pub fn draw(self: *World) void {
        var bodies = &global_world.bodies.toSlice();
        var i: usize = 0;
        while (i < bodies.len) : (i += 1) {
            var body: *Body = &bodies.ptr[i];
            if (!body.id.isAlive()) { continue; }
            body.draw();
        }
    }

    pub fn update(self: *World, delta: f32) void {
        // TODO: This can be made a lot smarter
        var bodies = &global_world.bodies.toSlice();
        {
            var i: usize = 0;
            while (i < bodies.len) : (i += 1) {
                var body: *Body = &bodies.ptr[i];
                if (!body.id.isAlive()) { continue; }
                body.update(delta);
            }
        }

        {
            var i: usize = 0;
            while (i < bodies.len) : (i += 1) {
                var j: usize = i + 1;
                while (j < bodies.len) : (j += 1) {
                    var a: *Body = &bodies.ptr[i];
                    if (!a.id.isAlive()) { continue; }
                    var b: *Body = &bodies.ptr[j];
                    if (!b.id.isAlive()) { continue; }
                    var c = a.overlaps(b);
                    if (c.depth > 0.0) {
                        // self.addCollision(c);
                        c.solve();
                    }
                }
            }
        }

        {
            var i: usize = 0;
            while (i < bodies.len) : (i += 1) {
                var body: *Body = &bodies.ptr[i];
                if (!body.id.isAlive()) { continue; }
                body.tryCopyBack();
            }
        }
    }
};
