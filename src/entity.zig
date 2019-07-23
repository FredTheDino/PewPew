use @import("import.zig");

const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh; 

const List = @import("std").ArrayList;

pub const Transform = struct {
    position: Vec3,
    rotation: Vec3,
    scale: f32,

    pub fn toMat(self: Transform) Mat4 {
        const scale = Mat4.scale(self.scale, self.scale, self.scale);
        const rotation = Mat4.rotation(self.rotation.x, self.rotation.y, self.rotation.z);
        const translation = Mat4.translation(self.position);
        return translation.mulMat(rotation.mulMat(scale));
    }
};

pub const Drawable = struct {
    mesh: *const Mesh,
    program: *const Shader,

    pub fn draw(self: Drawable, entity: *Entity) void {
        // TODO: Is this needed?
        self.program.bind();
        if (entity.has(TRANSFORM)) {
            const c = entity.get(TRANSFORM);
            self.program.sendModel(c.transform.toMat());
        }
        self.mesh.drawTris();
    }
};

pub const TRANSFORM = C{ .transform = undefined };
pub const DRAWABLE = C{ .drawable = undefined };

const C = Component;
pub const Component = union(enum) {
    // TODO: Can I make this into a macro somehow?
    transform: Transform,
    drawable: Drawable,

    fn noop() void {}

    fn update(self: C, entity: *Entity, delta: f32) void {
        switch (self) {
            C.drawable => |c| c.draw(entity),
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
            else => unreachable,
        };
    }
};

pub const Entity = struct {
    id: EntityID,
    // TODO: Should this be passed into the update function?
    // Then we don't have to waste space on it, and these
    // entities would be leaner.
    system: *ECS,
    active_components: [@memberCount(C)]bool,
    components: [@memberCount(C)]C,

    pub fn create(self: *ECS) Entity {
        var e = Entity{
            .active_components = []bool{false} ** @memberCount(C),
            .components = undefined,
            .system = self,
            .id = EntityID { .pos = 0, .gen = 0, },
        };
        return e;
    }

    pub fn addAll(self: *Entity, args: ...) void {
        comptime var i = 0;
        inline while (i < args.len) : (i += 1) {
            self.add(args[i]);
        }
    }

    pub fn add(self: *Entity, component: var) void {
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

    pub fn has(self: Entity, comptime component: C) bool {
        return self.active_components[@enumToInt(component)];
    }

    // TODO: Is there someway to wrap this?
    // Should I make explicit methods for each component?
    // As it is now I think it works... A tad verbose though.
    pub fn get(self: Entity, comptime component: C) C {
        return self.components[@enumToInt(component)];
    }

    pub fn update(self: *Entity, delta: f32) void {
        for (self.active_components) |active, i| {
            if (!active) continue;
            self.components[i].update(self, delta);
        }
    }
};

pub const EntityID = struct {
    pos: i32,
    gen: u32,

    pub fn isAlive(self: EntityID) bool {
        return self.pos >= 0;
    }

    pub fn get(self: EntityID, system: *ECS) ?*Entity {
        return system.get(self);
    }
};

pub const ECS = struct {
    // List of entities
    // Add / Remove / Get
    const EntityList = List(Entity);
    const IDList = List(EntityID);
    
    entities: EntityList,
    next_free: i32,

    pub fn create() ECS {
        return ECS{
            .entities = EntityList.init(A),
            .next_free = 0,
        };
    }

    //
    pub fn genId(self: *ECS, e: *Entity) ?EntityID {
        var id = EntityID{ .pos = 0, .gen = 0, };
        if (self.next_free < 0) {
            const i = @intCast(usize, 1 - self.next_free);
            const next_id = self.entities.at(i).id;
            id = EntityID{
                .pos = @intCast(i32, i),
                .gen = next_id.gen + 1,
            };
            self.next_free = -(1 + next_id.pos);
        } else {
            id = EntityID{
                .pos = self.next_free,
                .gen = 0,
            };
            // TODO: Is this needed?
            self.entities.ensureCapacity(@intCast(usize, id.pos + 1)) catch |err| switch(err) {
                error.OutOfMemory => return null,
            };
            self.next_free += 1;
        }
        e.id = id;
        // TODO: Might be smart to add it here..
        return id;
    }

    // TODO: Remove method
    
    // TODO: Is this redundant? It can be stored on the ID.
    pub fn get(self: *ECS, id: EntityID) ?*EntityID {
        var e = self.entities.get(id.pos) catch return null;
        if (e.id.gen != id.gen) return null;
        return e;
    }

    pub fn createWith(self: *ECS, args: ...) EntityID {
        var e = Entity.create(self);
        e.addAll(args);
        var id = self.genId(&e) orelse return EntityID{ .pos = -1, .gen = 0, };
        self.entities.set(@intCast(usize, id.pos), e);
        return id;
    }

    pub fn update(self: *ECS, delta: f32) void {
        var i: usize = 0;
        while (i < self.entities.count()): (i += 1) {
            var e = self.entities.at(i);
            if (!e.id.isAlive()) continue;
            e.update(delta);
        }
    }
};

