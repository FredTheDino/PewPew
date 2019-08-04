/// TODO(ed): This code assumes there's only ONE entity system
/// at play at a time. Some convenience methods will not work
/// if there are more than that.
use @import("import.zig");
const Input = @import("input.zig");
const Keys = InputHandler.KeyType;

// TODO(ed): Maybe add a way to add requirements to components,
// since they require each other.

// TODO: Is this a compiler bug???? This is wierd...

const Phy = @import("collision.zig");
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
    damping: f32,

    pub fn still() Movable {
        return Movable{
            .linear = V3(0, 0, 0),
            .rotational = V3(0, 0, 0),
            .damping = 0.0
        };
    }

    pub fn update(self: Movable, entity: *Entity, delta: f32) void {
        // Don't move it twice.
        if (entity.has(CT.physics)) return;
        if (!entity.has(CT.transform)) return;
        var t: *Transform = entity.getTransform();
        var m: *Movable = entity.getMoveable();
        t.position = t.position.add(m.linear.scale(delta));
        t.rotation = t.rotation.byVector(m.rotational, delta);
        const damping = math.pow(f32, 1 - m.damping, delta);
        m.linear = m.linear.scale(damping);
        m.rotational = m.rotational.scale(damping);
    }
};

pub const Physics = struct {
    body: Phy.BodyID,

    pub fn isOverlapping(self: Physics) bool {
        return self.body.dep().overlapping;
    }

    pub fn create(dimension: Vec3, moveable: bool) Physics {
        return Physics{
            .body = Phy.global_world.create(dimension, moveable),
        };
    }

    pub fn connect(self: *Physics, owner: EntityID) void {
        self.body.dep().entity = owner;
    }
};

pub const Player = struct {
    // Camera
    const FLOOR_HEIGHT: f32 = 0;
    yaw: f32,
    pitch: f32,

    height: f32,
    speed: f32,
    jump_speed: f32,
    gravity: f32,

    id: Input.PlayerId,

    pub fn create(id: PlayerId) Player {
        return Player{
            .yaw = 0,
            .pitch = 0,
            .height = 1.5,
            .speed = 10.0,
            .jump_speed = 8.0,
            .gravity = -10.0,
            .id = id,
        };
    }


    pub fn update(self: Player, entity: *Entity, delta: f32) void {
        // TODO: Agressive, it crashes if it doesn't exist, is this smart?
        const movable: *Movable = entity.getMoveable();
        // NOTE: Position for feet!
        const transform: *Transform = entity.getTransform();
        const player: *Player = entity.getPlayer();
        // TODO: Acceleration

        var movement: Vec4 = V4(
                Input.value(player.id, Input.Event.MOVE_X) * delta,
                0,
                Input.value(player.id, Input.Event.MOVE_Y) * delta,
                0);

        const rotation = Mat4.rotation(0, self.yaw, 0);
        movable.linear = movable.linear.add(rotation.mulVec(movement).toV3());

        const damping = math.pow(f32, 1.0 - 0.9, delta);
        const y_vel = movable.linear.y;
        movable.linear = movable.linear.scale(damping);
        movable.linear.y = y_vel;

        player.yaw -= Input.value(player.id, Input.Event.LOOK_X) * delta;
        player.pitch += Input.value(player.id, Input.Event.LOOK_Y) * delta;

        if (transform.position.y <= FLOOR_HEIGHT) {
            transform.position.y = 0;
            movable.linear.y = 0;
            if (Input.pressed(player.id, Input.Event.JUMP)) {
                movable.linear.y = self.jump_speed;
            }
        } else {
            movable.linear.y += self.gravity * delta;
        }
    }

    pub fn getViewMatrix(self: Player, entity: *Entity) Mat4 {
        const pos = entity.getTransform().position;
        const translation = Mat4.translation(V3(0, self.height, 0).sub(pos));
        const rotation = Mat4.rotation(self.pitch, self.yaw, 0);
        return rotation.mulMat(translation);
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
        // TODO: Remove this.
        unreachable;
    }
};

const CT = ComponentType;
const C = Component;

pub const ComponentType = enum {
    // Update order:
    physics,
    player,
    transform,
    gravity,
    movable,

    drawable,
};

pub const Component = union(ComponentType) {
    // TODO: Can I make this into a macro somehow?
    physics: Physics,
    player: Player,
    transform: Transform,
    gravity: Gravity,
    movable: Movable,

    drawable: Drawable,

    fn update(self: C, entity: *Entity, delta: f32) void {
        switch (self) {
            C.drawable => |c| c.draw(entity),
            C.gravity => |c| c.update(entity, delta),
            C.movable => |c| c.update(entity, delta),
            C.player => |c| c.update(entity, delta),
            else => {},
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
            Player => C{
                .player = component,
            },
            Physics => C{
                .physics = component,
            },
            else => {
                std.debug.warn("FOREGOT TO ADD TO WRAP\n");
                unreachable;
            },
        };
    }
};

// TODO: This style isn't that good... It needs a lot of abstraction
// or to be something else...
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
            if (wrapped == CT.physics) {
                wrapped.physics.connect(self.id);
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
    // TODO: Maybe actual error messages...
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

    pub fn getPlayer(self: *Entity) *Player {
        return &(self.get(CT.player) orelse unreachable).player;
    }

    pub fn getPhysics(self: *Entity) *Physics {
        return &(self.get(CT.physics) orelse unreachable).physics;
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

    // Better name?
    pub fn dep(self: EntityID) *Entity {
        return self.de() orelse unreachable;
    }
};

var global_ecs: ECS = undefined;

pub const ECS = struct {
    // List of entities
    // Add / Remove / Get
    const EntityList = List(Entity);

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
        var id = self.genId() orelse unreachable;
        var e = Entity.init(self);
        e.id = id;
        e.add(args);
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
        const entities = self.entities.toSlice();
        var c: usize = 0;
        while (c < @memberCount(CT)) : (c += 1) {
            var i: usize = 0;
            while (i < self.entities.count()): (i += 1) {
                var e: *Entity = &entities[i];
                if (!e.id.isAlive() or e.id.pos != @intCast(i32, i)) continue;
                e.update(@intToEnum(CT, @intCast(@TagType(CT), c)), delta);
            }
        }
    }
};

