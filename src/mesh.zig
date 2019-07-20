use @import("import.zig");

const DebugDraw = struct {
    colors: []Vec3,
    line_buckets: []Mesh,
};

pub const Mesh = struct {

    gl_object: c_uint,
    gl_buffer: c_uint,
    gl_indexbuffer: c_uint,
    used_verticies: usize,
    draw_length: usize,

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

    pub fn createSimple(vertices: []const Vertex) Mesh {
        var mesh: Mesh = undefined;
        mesh.gl_indexbuffer = 0;
        glGenVertexArrays(1, &mesh.gl_object);
        glBindVertexArray(mesh.gl_object);

        glGenBuffers(1, &mesh.gl_buffer);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_buffer);

        mesh.draw_length = vertices.len;
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
        std.debug.warn("len: {}\n", mesh.draw_length);
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

    pub fn draw(self: Mesh) void {
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

};
