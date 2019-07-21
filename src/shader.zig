use @import("import.zig");

const File = std.os.File;

// TODO: Cache the locations.

pub const Shader = struct {

    program: c_uint,

    /// Quick and dirty string replace, has sever 
    /// limitations since the replacement
    /// and find string has to be the same length.
    fn replace(str: []u8, 
            find: [] const u8, 
            replacement: [] const u8) void {
        assert(find.len == replacement.len);
        var i: u32 = 0;
outer:
        while (i < str.len) : ({ i += 1; }) {
            for (find) |c, j| {
                if (c != str[i + j])
                    continue :outer;
            }
            for (replacement) |c, j| {
                str[i + j] = c;
            }
        }
    }

    /// Compiles a Vertex or Fragment shader.
    fn compile_shader(path: []const u8,
                      shader_type: c_uint, 
                      source_ptr: ?[*]const u8, 
                      source_len: c_int) !c_uint {
        const shader = glCreateShader(shader_type);
        glShaderSource(shader, 1, &source_ptr, &source_len);
        glCompileShader(shader);

        var ok: c_int = undefined;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
        if (ok != 0) return shader;

        var error_buffer: [] u8 = A.alloc(u8, 512) catch unreachable;
        var length: c_int = @intCast(c_int, error_buffer.len);
        glGetShaderInfoLog(shader, length, &length, error_buffer.ptr);
        std.debug.warn("Compilation failed \"{}({})\":\n\t{}", 
                       path,
                       shader_type == GL_VERTEX_SHADER,
                       error_buffer[0..@intCast(usize, length)]);
        return error.VertexCompilationFailed;
    }

    /// Compiles an entire program. Assuming that both
    /// the vertex and fragment shader are in the same
    /// file.
    pub fn compile(path: []const u8) !Shader {
        // Read in file
        var file = try File.openRead(path);
        var file_size = try File.getEndPos(file);
        var buffer = try A.alloc(u8, file_size);
        var read = File.read(file, buffer);


        const source_ptr: ?[*]const u8 = buffer.ptr;
        const source_len = @intCast(c_int, buffer.len);

        const vertex = try compile_shader(path,
                                      GL_VERTEX_SHADER,
                                      source_ptr,
                                      source_len);
        defer glDeleteShader(vertex);

        replace(buffer, "#define VERT", "#define FRAG");
        const fragment = try compile_shader(path,
                                        GL_FRAGMENT_SHADER,
                                        source_ptr,
                                        source_len);
        defer glDeleteShader(fragment);

        var shader_program = Shader {
            .program = glCreateProgram(),
        };

        glAttachShader(shader_program.program, vertex);
        glAttachShader(shader_program.program, fragment);
        glLinkProgram(shader_program.program);
        glDetachShader(shader_program.program, vertex);
        glDetachShader(shader_program.program, fragment);

        var ok: c_int = undefined;
        glGetProgramiv(shader_program.program, GL_LINK_STATUS, &ok);
        if (ok != 0) return shader_program;
        
        var error_buffer: [] u8 = A.alloc(u8, 512) catch unreachable;
        var length = @intCast(c_int, error_buffer.len);
        glGetProgramInfoLog(shader_program.program, 
                            length, 
                            &length, 
                            error_buffer.ptr);
        std.debug.warn("Linking failed \"{}\":\n\t{}", 
                       path,
                       error_buffer[0..@intCast(usize, length)]);
        glDeleteProgram(shader_program.program);
        @panic("Program linking failed!");
    }

    /// Bind the shader for usage.
    pub fn bind(shader: Shader) void {
        glUseProgram(shader.program);
    }

    /// Update the times
    pub fn update(shader: Shader) void {
        const loc_t = glGetUniformLocation(shader.program, c"time");
        glUniform1f(loc_t, @intToFloat(f32, SDL_GetTicks()) / 1000.0);
    }

    /// Update the camera
    pub fn sendCamera(shader: Shader, proj: Mat4, view: Mat4) void {
        const loc_view = glGetUniformLocation(shader.program, c"view");
        const view_arr: [*c]const f32 = @alignCast(4, &view.v[0][0]);
        glUniformMatrix4fv(loc_view, 1, 1, view_arr);

        const loc_proj = glGetUniformLocation(shader.program, c"proj");
        const proj_arr: [*c]const f32 = @alignCast(4, &proj.v[0][0]);
        glUniformMatrix4fv(loc_proj, 1, 1, proj_arr);
    }
    
    /// Send in a color
    pub fn color(shader: Shader, c: Vec3) void {
        const loc_use_color = glGetUniformLocation(shader.program, c"use_color");
        const loc_color = glGetUniformLocation(shader.program, c"color");
        glUniform1i(loc_use_color, 1);
        glUniform3f(loc_color, c.x, c.y, c.z);
    }

    /// Don't render any colors
    pub fn disableColor(shader: Shader) void {
        const loc_use_color = glGetUniformLocation(shader.program, c"use_color");
        glUniform1i(loc_use_color, 0);
    }

    /// Set where to draw something.
    pub fn sendModel(shader: Shader, model: Mat4) void {
        const loc_model = glGetUniformLocation(shader.program, c"model");
        const model_arr: [*c]const f32 = @alignCast(4, &model.v[0][0]);
        glUniformMatrix4fv(loc_model, 1, 1, model_arr);
    }
};
