use @import("import.zig");

const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;

// TODO: Needs a lot of beatification!

pub const ComponentType = enum {
    drawable,
    transform,
};

pub const Transform = struct {
    position: Vec3,
    rotation: Vec3,
    scale: f32,

    pub fn toMat(self: Transform) Mat4 {
        const scale = Mat4.scale(self.scale, self.scale, self.scale);
        const rotation = Mat4.rotation(self.rotation.x,
                                       self.rotation.y,
                                       self.rotation.z);
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
        if (entity.has(ComponentType.transform)) {
            const c = entity.get(ComponentType.transform);
            self.program.sendModel(c.transform.toMat());
        }
        self.mesh.draw();
    }
};

fn noop() void {}

pub const Component = union(ComponentType) {
    drawable: Drawable,
    transform: Transform,

    pub fn update(self: Component, entity: *Entity, delta: f32) void {
        switch (self) {
            ComponentType.drawable => |c| c.draw(entity),
            ComponentType.transform => noop(),
        }
    }
};

pub const Entity = struct {
    active_components: [@memberCount(ComponentType)] bool,
    components: [@memberCount(ComponentType)] Component,

    pub fn create() Entity {
        return Entity {
            .active_components = []bool{false} ** @memberCount(ComponentType),
            .components = undefined,
        };
    }

    pub fn add(self: *Entity, component: Component) bool {
        const component_type = ComponentType(component);
        const pos = @enumToInt(component_type);
        const new = !self.active_components[pos];
        self.active_components[pos] = true;
        self.components[pos] = component;
        return new;
    }

    pub fn has(self: Entity, component: ComponentType) bool {
        return self.active_components[@enumToInt(component)];
    }

    pub fn get(self: Entity, component: ComponentType) Component {
        return self.components[@enumToInt(component)];
    }

    pub fn update(self: *Entity, delta: f32) void {
        for(self.active_components) |active, i| {
            if (!active) continue;
            self.components[i].update(self, delta);
        }
    }
};


