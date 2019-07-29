use @import("import.zig");

// TODO: Remove

pub const Shader = @import("shader.zig").Shader;

pub const Vertex = packed struct {
    x: f32,
    y: f32,
    z: f32,

    nx: f32,
    ny: f32,
    nz: f32,

    u: f32,
    v: f32,

    pub fn p(x: f32, y: f32, z: f32) Vertex {
        return Vertex{
            .x = x,
            .y = y,
            .z = z,

            .nx = 0,
            .ny = 0,
            .nz = 0,

            .u = 0,
            .v = 0,
        };
    }

    pub fn pt(x: f32, y: f32, z: f32, u: f32, v: f32) Vertex {
        return Vertex{
            .x = x,
            .y = y,
            .z = z,

            .nx = 0,
            .ny = 0,
            .nz = 0,

            .u = u,
            .v = v,
        };
    }

    pub fn pnt(x: f32, y: f32, z: f32, nx: f32, ny: f32, nz: f32, u: f32, v: f32) Vertex {
        return Vertex{
            .x = x,
            .y = y,
            .z = z,

            .nx = nx,
            .ny = ny,
            .nz = nz,

            .u = u,
            .v = v,
        };
    }
};

pub const DebugDraw = struct {
    pub var gfx_util: DebugDraw = undefined;
    const MAX_LINES = 100;
    line_mesh: Mesh,
    line_colors: [MAX_LINES]Vec3,
    lines_used: usize,

    const MAX_POINTS = 100;
    point_mesh: Mesh,
    point_colors: [MAX_POINTS]Vec3,
    points_used: usize,

    pub fn init() *DebugDraw {
        gfx_util.line_mesh = Mesh.createEmpty(MAX_LINES * 2);
        gfx_util.lines_used = 0;
        gfx_util.point_mesh = Mesh.createEmpty(MAX_POINTS);
        gfx_util.points_used = 0;
        return &gfx_util;
    }

    pub fn point(self: *DebugDraw, p: Vec3, color: Vec3) void {
        const current = self.points_used;
        if (current == MAX_LINES) return;
        self.points_used += 1;
        self.point_colors[current] = color;
        self.point_mesh.append(Vertex.p(p.x, p.y, p.z));
    }

    pub fn line(self: *DebugDraw, a: Vec3, b: Vec3, color: Vec3) void {
        const current = self.lines_used;
        if (current == MAX_LINES) return;
        self.line_colors[current] = color;
        self.lines_used += 1;
        self.line_mesh.append(Vertex.p(a.x, a.y, a.z));
        self.line_mesh.append(Vertex.p(b.x, b.y, b.z));
    }

    pub fn draw(self: *DebugDraw, shader: Shader) void {
        shader.sendModel(Mat4.identity());

        var i: usize = undefined;
        i = 0;
        while (i != self.lines_used) : (i += 1) {
            shader.color(self.line_colors[i]);
            self.line_mesh.drawLine(@intCast(c_int, i * 2));
        }

        i = 0;
        while (i != self.points_used) : (i += 1) {
            shader.color(self.point_colors[i]);
            self.point_mesh.drawPoint(@intCast(c_int, i));
        }

        self.line_mesh.clear();
        self.lines_used = 0;
        self.point_mesh.clear();
        self.points_used = 0;
        shader.disableColor();
    }
};

pub const Texture = struct {
    gl_texture: c_uint,
    width: u32,
    height: u32,

    pub fn load(path: []const u8) !Texture {
        const warn = @import("std").debug.warn;
        const File = @import("std").os.File;
        var texture: Texture = undefined;

        var file = try File.openRead(path);
        var file_size = try File.getEndPos(file);
        var buffer = try A.alloc(u8, file_size);
        defer A.free(buffer);

        _ = try File.read(file, buffer);
        var data = stbi_load_from_memory(@ptrCast(* u8, buffer.ptr),
                                         @intCast(c_int, file_size),
                                         @ptrCast(*c_int, &texture.width),
                                         @ptrCast(*c_int, &texture.height),
                                         @intToPtr(*allowzero c_int, 0),
                                         0);
        glGenTextures(1, &texture.gl_texture);
        glBindTexture(GL_TEXTURE_2D, texture.gl_texture);

        // TODO: Way to change these when loading or maybe afterwards...
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_RGBA,
                     @intCast(c_int, texture.width),
                     @intCast(c_int, texture.height),
                     @intCast(c_int, 0),
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     @ptrCast(*const c_void, data));
        // Is this really needed?
        glGenerateMipmap(GL_TEXTURE_2D);

        glBindTexture(GL_TEXTURE_2D, 0);

        stbi_image_free(@ptrCast(*c_void, data));
        return texture;
    }

    pub fn bind(self: Texture, target: u8) void {
        glActiveTexture(GL_TEXTURE0 + @intCast(c_uint, target));
        glBindTexture(GL_TEXTURE_2D, self.gl_texture);
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
        glBindBuffer(GL_ARRAY_BUFFER, self.gl_buffer);
        glBufferSubData(GL_ARRAY_BUFFER, @intCast(c_long, self.used_verticies * @sizeOf(Vertex)), @sizeOf(Vertex), @ptrCast(*const c_void, &vertex));

        self.used_verticies += 1;
        self.draw_length += 1;

        glBindVertexArray(0);
    }

    fn setupAttribArray() void {
        // Position
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0,
                              3,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 0));
        // Normal
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1,
                              3,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 3 * @sizeOf(real)));

        // Texture
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2,
                              2,
                              GL_FLOAT,
                              0,
                              @sizeOf(Vertex),
                              @intToPtr(*allowzero c_void, 6 * @sizeOf(real)));

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
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_long, size * @sizeOf(Vertex)), @intToPtr(*allowzero c_void, 0), GL_DYNAMIC_DRAW);

        setupAttribArray();

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
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_long, vertices.len * @sizeOf(Vertex)), &vertices[0], GL_STATIC_DRAW);

        setupAttribArray();

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
        glBufferData(GL_ARRAY_BUFFER, @intCast(c_long, vertices.len * @sizeOf(Vertex)), &vertices[0], GL_STATIC_DRAW);

        glBufferData(GL_ELEMENT_ARRAY_BUFFER, @intCast(c_long, indicies.len * @sizeOf(c_int)), &indicies[0], GL_STATIC_DRAW);

        setupAttribArray();

        glBindVertexArray(0);
        return mesh;
    }

    pub fn drawTris(self: Mesh) void {
        // Fake transparency, looks really cool..
        // glEnable(GL_POLYGON_STIPPLE);
        // var pattern = []u32 {0} ** 32;
        // for (pattern) |_, i| {
        //     if (i % 2 == 0) {
        //         pattern[i] = 0xAAAAAAAA;
        //     } else {
        //         pattern[i] = 0x55555555;
        //     }
        // }
        // glPolygonStipple(@ptrCast(*const u8, &pattern));
        glBindVertexArray(self.gl_object);
        const length = @intCast(c_int, self.draw_length);
        if (self.gl_indexbuffer == 0) {
            glDrawArrays(GL_TRIANGLES, 0, @intCast(c_int, length));
        } else {
            glDrawElements(GL_TRIANGLES, length, GL_UNSIGNED_INT, @intToPtr(*allowzero c_void, 0));
        }
        glBindVertexArray(0);
    }

    pub fn drawLine(self: Mesh, index: c_int) void {
        glBindVertexArray(self.gl_object);
        if (self.gl_indexbuffer == 0) {
            glLineWidth(10.0);
            glDrawArrays(GL_LINES, index, @intCast(c_int, 2));
        } else {
            unreachable;
        }
        glBindVertexArray(0);
    }

    pub fn drawPoint(self: Mesh, index: c_int) void {
        glBindVertexArray(self.gl_object);
        if (self.gl_indexbuffer == 0) {
            glPointSize(10.0);
            glDrawArrays(GL_POINTS, index, @intCast(c_int, 1));
        } else {
            unreachable;
        }
        glBindVertexArray(0);
    }
};
