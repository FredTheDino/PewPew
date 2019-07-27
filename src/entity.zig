/// TODO(ed): This code assumes there's only ONE entity system
/// at play at a time. Some convenience methods will not work
/// if there are more than that.
use @import("import.zig");

// TODO(ed): Maybe add a way to add requirements to components,
// since they require each other.

const GFX = @import("graphics.zig");
const List = @import("std").ArrayList;

pub const Transform = struct {
    position: Vec3,
    rotation: Quat,
    scale: f32,

    pub fn at(p: Vec3) Transform {
        return Transform{
            .position = p,
            .rotation = Quat.identity(),
            .scale = 1,
        };
    }

    pub fn toMat(self: Transform) Mat4 {
        const scale = Mat4.scale(self.scale, self.scale, self.scale);
        const rotation = self.rotation.toMat();
        const translation = Mat4.translation(self.position);
        return translation.mulMat(rotation.mulMat(scale));
    }
};

pub const Movable = struct {
    linear: Vec3,
    rotational: Vec3,

    pub fn still() Movable {
        return Movable{
            .linear = V3(0, 0, 0),
            .rotational = V3(0, 0, 0),
        };
    }

    pub fn update(self: Movable, entity: *Entity, delta: f32) void {
        if (!entity.has(CT.transform)) return;
        var t: *Transform = entity.getTransform();
        t.position = t.position.add(self.linear.scale(delta));
        t.rotation = t.rotation.byVector(self.rotational, delta);
    }
};

pub const Drawable = struct {
    mesh: *const GFX.Mesh,
    program: *const GFX.Shader,

    pub fn draw(self: Drawable, entity: *Entity) void {
        // TODO: Is this needed?
        if (!entity.has(CT.transform)) return;
        self.program.bind();
        const mat = entity.getTransform().toMat();
        mat.gfxDump();
        //mat.dump();
        self.program.sendModel(mat);
        self.mesh.drawTris();
    }
};

pub const Gravity = struct {
    acceleration: f32,

    pub fn update(self: Gravity, entity: *Entity, delta: f32) void {
        if (!entity.has(CT.transform)) return;
        if (!entity.has(CT.movable)) return;
        entity.getMoveable().linear.y += self.acceleration * delta;
    }
};

const CT = ComponentType;
const C = Component;

pub const ComponentType = enum {
    // Update order:
    transform,
    gravity,
    movable,

    drawable,
};

pub const Component = union(ComponentType) {
    // TODO: Can I make this into a macro somehow?
    transform: Transform,
    gravity: Gravity,
    movable: Movable,

    drawable: Drawable,

    fn noop() void {}

    fn update(self: C, entity: *Entity, delta: f32) void {
        switch (self) {
            C.drawable => |c| c.draw(entity),
            C.gravity => |c| c.update(entity, delta),
            C.movable => |c| c.update(entity, delta),
            C.transform => noop(),
        }
    }

    pub fn wrap(component: var) C {
        return switch (@typeOf(component)) {
            Drawable => C{
                .drawable = component,
            },
            Transform => C{
                .transform = component,
            },
            Gravity => C{
                .gravity = component,
            },
            Movable => C{
                .movable = component,
            },
            else => {
                std.debug.warn("FOREGOT TO ADD TO WRAP\n");
                unreachable;
            },
        };
    }
};

pub const Entity = struct {
    id: EntityID,
    // TODO: Should this be passed into the update function?
    // Then we don't have to waste space on it, and these
    // entities would be leaner.
    active_components: [@memberCount(C)]bool,
    components: [@memberCount(C)]C,

    pub fn init(self: *ECS) Entity {
        var e = Entity{
            .active_components = []bool{false} ** @memberCount(C),
            .components = undefined,
            .id = EntityID { .pos = 0, .gen = 0, },
        };
        return e;
    }

    pub fn add(self: *Entity, args: ...) void {
        comptime var i = 0;
        inline while (i < args.len) : (i += 1) {
            var component = args[i];
            var wrapped: Component = undefined;
            if (@typeOf(component) == C) {
                wrapped = component;
            } else {
                wrapped = C.wrap(component);
            }
            const pos = @enumToInt(wrapped);
            self.active_components[pos] = true;
            self.components[pos] = wrapped;
        }
    }

    pub fn remove(self: *Entity, args: ...) void {
        comptime var i = 0;
        inline while (i < args.len) : (i += 1) {
            self.active_components[@enumToInt(args[i])] = false;
        }
    }

    pub fn has(self: Entity, component: CT) bool {
        return self.active_components[@enumToInt(component)];
    }

    // TODO: Is there someway to wrap this?
    // Should I make explicit methods for each component?
    // As it is now I think it works... A tad verbose though.
    pub fn get(self: *Entity, comptime component: CT) ?*C {
        if (!self.has(component)) return null;
        return &self.components[@enumToInt(component)];
    }

    // Convenience functions, when you promise things actually exist.
    pub fn getTransform(self: *Entity) *Transform {
        return &(self.get(CT.transform) orelse unreachable).transform;
    }

    pub fn getDrawable(self: *Entity) *Drawable {
        return &(self.get(CT.drawable) orelse unreachable).drawable;
    }

    pub fn getGravity(self: *Entity) *Gravity {
        return &(self.get(CT.gravity) orelse unreachable).gravity;
    }

    pub fn getMoveable(self: *Entity) *Movable {
        return &(self.get(CT.movable) orelse unreachable).movable;
    }

    pub fn update(self: *Entity, component: CT, delta: f32) void {
        if (!self.has(component)) return;
        const i = @enumToInt(component);
        self.components[i].update(self, delta);
    }
};

pub const EntityID = struct {
    pos: i32,
    gen: u32,

    pub fn isAlive(self: EntityID) bool {
        return self.pos >= 0;
    }

    pub fn de(self: EntityID) ?*Entity {
        var e: *Entity = &global_ecs.entities.toSlice()[@intCast(usize, self.pos)];
        if (e.id.gen != self.gen or e.id.pos != self.pos) return null;
        return e;
    }

    pub fn deNoNull(self: EntityID) *Entity {
        return self.de() orelse unreachable;
    }
};

var global_ecs: ECS = undefined;

pub const ECS = struct {
    // List of entities
    // Add / Remove / Get
    const EntityList = List(Entity);
    const IDList = List(EntityID);

    entities: EntityList,
    next_free: i32,

    pub fn init() *ECS {
        global_ecs = ECS{
            .entities = EntityList.init(A),
            .next_free = 0,
        };
        return &global_ecs;
    }

    fn genId(self: *ECS) ?EntityID {
        var id = EntityID{ .pos = 0, .gen = 0, };
        if (self.next_free < 0) {
            const i = @intCast(usize, -(1 + self.next_free));
            id = self.entities.at(i).id;
            self.next_free = id.pos;
            id.pos = @intCast(i32, i);
        } else {
            id = EntityID{
                .pos = self.next_free,
                .gen = 0,
            };
            // TODO: Is this needed?
            _ = self.entities.addOne()
            catch |err| switch(err) {
                error.OutOfMemory => return null,
            };
            self.next_free += 1;
        }
        return id;
    }

    pub fn create(self: *ECS, args: ...) EntityID {
        var e = Entity.init(self);
        e.add(args);
        var id = self.genId() orelse unreachable;
        e.id = id;
        self.entities.set(@intCast(usize, id.pos), e);
        return id;
    }

    pub fn remove(self: *ECS, args: ...) void {
        comptime var i = 0;
        inline while(i < args.len) : (i += 1) {
            const id: EntityID = args[i];
            const e: *Entity = id.de() orelse continue;
            const curr = self.next_free;
            self.next_free = -(1 + e.id.pos);
            e.id.pos = curr;
            e.id.gen += 1;
        }
    }

    pub fn update(self: *ECS, delta: f32) void {
        var c: usize = 0;
        while (c < @memberCount(CT)) : (c += 1) {
            var i: usize = 0;
            while (i < self.entities.count()): (i += 1) {
                var e: *Entity = &self.entities.toSlice()[i];
                if (!e.id.isAlive() or e.id.pos != @intCast(i32, i)) continue;
                e.update(@intToEnum(CT, @intCast(@TagType(CT), c)), delta);
            }
        }
    }
};

