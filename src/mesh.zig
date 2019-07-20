use @import("import.zig");

const Shader = @import("shader.zig").Shader;
const List = @import("std").ArrayList;
const DA = @import("std").heap.DirectAllocator.init();
var A = DA.allocator;

pub const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,
    pub fn p(x: f32, y: f32, z: f32) Vertex {
        return Vertex {
            .x = x,
            .y = y,
            .z = z,
        };
    }

//        pub fn pc(x: f32, y: f32, z: f32, r: f32, g: f32, b: f32) Vertex {
//            return Vertex { .x = x, .y = y, .z = z, .r = r, .g = g, .b = b, };
//        }
};

pub const DebugDraw = struct {
    const ColorList = List(Vec3);
    const MeshList = List(Mesh);

    const LINES_PER_BUCKET = 200;
    colors: ColorList,
    buckets: MeshList,

    // TODO: Take in allocator
    pub fn init() DebugDraw {
        var dd = DebugDraw {
            .colors = ColorList.init(&A),
            .buckets = MeshList.init(&A),
        };
        dd.buckets.append(Mesh.createEmpty(LINES_PER_BUCKET * 2)) catch unreachable;
        return dd;
    }

    pub fn drawLine(self: *DebugDraw, p_a: Vec3, p_b: Vec3, color: Vec3) void {
        self.colors.append(color) catch unreachable;
        var bucket: Mesh = self.buckets.at(self.buckets.len - 1);
        if (bucket.used_verticies == bucket.total_verticies) {
            // We need a new bucket
            bucket = Mesh.createEmpty(LINES_PER_BUCKET * 2);
            self.buckets.append(bucket) catch unreachable;

        }
        bucket.append(Vertex {
            .x = p_a.x,
            .y = p_a.y,
            .z = p_a.z,
        });
        bucket.append(Vertex {
            .x = p_b.x,
            .y = p_b.y,
            .z = p_b.z,
        });
        self.buckets.set(self.buckets.len - 1, bucket);
    }

    pub fn draw(self: *DebugDraw, shader: Shader) void {
        {
            var i: usize = 0;
            while (i != self.colors.len) : ( i += 1 ) {
                shader.color(self.colors.at(i));
                const bucket = @divFloor(i, LINES_PER_BUCKET);
                const line_id = i - bucket * LINES_PER_BUCKET;
                self.buckets.at(bucket).drawLine(@intCast(c_int, line_id));
            }
        }

        {
            self.colors.resize(0) catch unreachable;
            var i: usize = 0;
            while (i != self.buckets.len) : ( i += 1 ) {
                self.buckets.at(i).clear();
            }
        }
        shader.disableColor();
    }
};

pub const Mesh = struct {

    gl_object: c_uint,
    gl_buffer: c_uint,
    gl_indexbuffer: c_uint,
    total_verticies: usize,
    used_verticies: usize,
    draw_length: usize,


    pub fn clear(self: *Mesh) void {
        self.used_verticies = 0;
        self.draw_length = 0;
    }

    pub fn append(self: *Mesh, vertex: Vertex) void {
        assert(self.used_verticies < self.total_verticies);

        glBindVertexArray(self.gl_object);
        glBufferSubData(GL_ARRAY_BUFFER,
                        @intCast(c_long, self.used_verticies * @sizeOf(Vertex)),
                        @sizeOf(Vertex),
                        @ptrCast(*const c_void, &vertex));

        self.used_verticies += 1;
        self.draw_length += 1;

        glBindVertexArray(0);
    }

    pub fn createEmpty(size: usize) Mesh {
        var mesh: Mesh = undefined;
        mesh.gl_indexbuffer = 0;
        glGenVertexArrays(1, &mesh.gl_object);
        glBindVertexArray(mesh.gl_object);

        glGenBuffers(1, &mesh.gl_buffer);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_buffer);

        mesh.draw_length = 0;
        mesh.used_verticies = 0;
        mesh.total_verticies = size;
        glBufferData(GL_ARRAY_BUFFER,
                     @intCast(c_long, size * @sizeOf(Vertex)),
                     @intToPtr(*allowzero c_void, 0),
                     GL_DYNAMIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0,
                              3,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 0));

        glBindVertexArray(0);
        return mesh;
    }

    pub fn createSimple(vertices: []const Vertex) Mesh {
        var mesh: Mesh = undefined;
        mesh.gl_indexbuffer = 0;
        glGenVertexArrays(1, &mesh.gl_object);
        glBindVertexArray(mesh.gl_object);

        glGenBuffers(1, &mesh.gl_buffer);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_buffer);

        mesh.draw_length = vertices.len;
        mesh.total_verticies = vertices.len;
        mesh.used_verticies = vertices.len;
        glBufferData(GL_ARRAY_BUFFER,
                     @intCast(c_long, vertices.len * @sizeOf(Vertex)),
                     &vertices[0],
                     GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0,
                              3,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 0));

        glBindVertexArray(0);
        return mesh;
    }

    pub fn createIndexed(vertices: []const Vertex, indicies: []const c_int) Mesh {
        var mesh: Mesh = undefined;
        glGenVertexArrays(1, &mesh.gl_object);
        glBindVertexArray(mesh.gl_object);

        glGenBuffers(1, &mesh.gl_buffer);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_buffer);
        glGenBuffers(1, &mesh.gl_indexbuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.gl_indexbuffer);

        mesh.draw_length = indicies.len;
        mesh.total_verticies = vertices.len;
        mesh.used_verticies = vertices.len;
        glBufferData(GL_ARRAY_BUFFER,
                     @intCast(c_long, vertices.len * @sizeOf(Vertex)),
                     &vertices[0],
                     GL_STATIC_DRAW);

        glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                     @intCast(c_long, indicies.len * @sizeOf(c_int)),
                     &indicies[0],
                     GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0,
                              3,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 0));

        glBindVertexArray(0);
        return mesh;

    }

    pub fn drawTris(self: Mesh) void {
        glBindVertexArray(self.gl_object);
        const length = @intCast(c_int, self.draw_length);
        if (self.gl_indexbuffer == 0) {
            glDrawArrays(GL_TRIANGLES, 0, @intCast(c_int, length));
        } else {
            glDrawElements(GL_TRIANGLES,
                           length,
                           GL_UNSIGNED_INT,
                           @intToPtr(*allowzero c_void, 0));
        }
        glBindVertexArray(0);
    }

    pub fn drawLine(self: Mesh, index: c_int) void {
        glBindVertexArray(self.gl_object);
        if (self.gl_indexbuffer == 0) {
            glLineWidth(10.0);
            glDrawArrays(GL_LINES, index * 2, @intCast(c_int, 2));
        } else {
            unreachable;
        }
        glBindVertexArray(0);
    }
};
