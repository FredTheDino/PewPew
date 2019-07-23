use @import("import.zig");

const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;

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
    active_components: [@memberCount(C)]bool,
    components: [@memberCount(C)]C,

    pub fn create() Entity {
        return Entity{
            .active_components = []bool{false} ** @memberCount(C),
            .components = undefined,
        };
    }

    pub fn createWith(args: ...) Entity {
        var self = create();
        self.addAll(args);
        return self;
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

    pub fn get(self: Entity, comptime component: C) C {
        return self.components[@enumToInt(component)];
        // var c = self.components[@enumToInt(component)];
        // return switch(c) {
        //     TRANSFORM => return &c.transform,
        //     DRAWABLE => return &c.drawable,
        // };
    }

    pub fn update(self: *Entity, delta: f32) void {
        for (self.active_components) |active, i| {
            if (!active) continue;
            self.components[i].update(self, delta);
        }
    }
};
