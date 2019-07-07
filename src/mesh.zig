use @import("import.zig");

pub const Mesh = struct {
    
    gl_object: c_uint,
    gl_buffer: c_uint,
    num_verticies: usize,

    pub const Vertex = packed struct {
        x: f32,
        y: f32,
        z: f32,
    };

    pub fn create(vertices: []const Vertex) Mesh {
        var mesh: Mesh = undefined;
        glGenVertexArrays(1, &mesh.gl_object);
        glBindVertexArray(mesh.gl_object);

        glGenBuffers(1, &mesh.gl_buffer);
        glBindBuffer(GL_ARRAY_BUFFER, mesh.gl_buffer);

        mesh.num_verticies = vertices.len;
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

    pub fn draw(self: Mesh) void {
        glBindVertexArray(self.gl_object);
        glDrawArrays(GL_TRIANGLES, 0, @intCast(c_int, self.num_verticies));
        glBindVertexArray(0);
    }

};
