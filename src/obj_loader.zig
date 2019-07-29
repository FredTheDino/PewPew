use @import("import.zig");

const Mesh = @import("graphics.zig").Mesh;
const Vertex = @import("graphics.zig").Vertex;
const ArrayList = std.ArrayList;
const FloatBuffer = ArrayList(real);
const VertexBuffer = ArrayList(Vertex);
const File = std.os.File;


fn nextLine(read_head: usize, buffer: []u8) usize {
    var new_head = read_head;
    while (new_head < buffer.len) : (new_head += 1) {
        if (buffer[new_head] == '\n') {
            break;
        }
    }
    new_head += 1;
    if (new_head < buffer.len)
        return new_head;
    return buffer.len;
}

fn readToAfterSpace(read_head: usize, buffer: []u8) usize {
    var new_head = read_head;
    var last_was_space = false;
    while (new_head < buffer.len) : (new_head += 1) {
        if (buffer[new_head] == ' ') {
            last_was_space = true;
        } else if (last_was_space) {
            break;
        }
    }
    return new_head;
}

fn isDigit(c: u8) bool {
    return '0' <= c and c <= '9';
}

fn toDigit(c: u8) u8 {
    return c - '0';
}

fn parseUInt(read_head: *usize, buffer: []u8) !u32 {
    var result: u32 = 0;
    var new_head = read_head.*;
    while (true) : (new_head += 1) {
        if (buffer.len <= new_head)
            return error.NotAValidInt;
        const c = buffer[new_head];
        if (!isDigit(c))
            break;
        result *= 10;
        result += toDigit(c);
    }
    if (read_head.* == new_head)
        return error.NotAValidInt;
    // Send out the new head
    read_head.* = new_head;
    return result;
}

fn noop() void {}

fn parseFloat(comptime Result: type, read_head: *usize, buffer: []u8) !Result {
    var result: Result = 0.0;
    var new_head = read_head.*;
    const negative: bool = buffer[new_head] == '-';

    if (negative) {
        new_head += 1;
    }

    var whole_part: u32 = 0;
    if (buffer.len <= new_head) return error.NotAValidFloat;
    switch(buffer[new_head]) {
        '0'...'9' => whole_part = try parseUInt(&new_head, buffer),
        '.' => noop(),
        else => return error.NotAValidFloat,
    }

    if (buffer[new_head] != '.') return error.NotAValidFloat;
    new_head += 1;

    var decimals: u32 = 0;
    var decimal_value: Result = 0.0;
    while (true) : (new_head += 1) {
        if (buffer.len < new_head)
            return error.NotAValidFloat;
        const c = buffer[new_head];
        if (!isDigit(c))
            break;
        decimals += 1;
        decimal_value *= 10;
        decimal_value += @intToFloat(Result, toDigit(c));
    }
    read_head.* = new_head;

    decimal_value /= math.pow(Result, 10, @intToFloat(Result, decimals));
    decimal_value += @intToFloat(Result, whole_part);
    if (negative) {
        return -decimal_value;
    }
    return decimal_value;
}

pub fn loadMesh(path: []const u8) !Mesh {
    // Read the text file
    // Parse all data points
    // Combine
    // Send as mesh

    var file = try File.openRead(path);
    var file_size = try File.getEndPos(file);
    var buffer = try A.alloc(u8, file_size);
    defer A.free(buffer);
    var buffer_size = try File.read(file, buffer);


    // Grouped 3
    var v_buffer = FloatBuffer.init(A);
    defer v_buffer.deinit();
    // Grouped 2
    var vt_buffer = FloatBuffer.init(A);
    defer vt_buffer.deinit();
    // Grouped 3
    var vn_buffer = FloatBuffer.init(A);
    defer vn_buffer.deinit();

    var verticies = VertexBuffer.init(A);
    defer verticies.deinit();

    var read_head: usize = 0;
    while (read_head < buffer_size) :
          (read_head = nextLine(read_head, buffer)) {
        switch (buffer[read_head]) {
            'v' => {
                read_head += 1;
                switch(buffer[read_head]) {
                ' ' => {
                    // X
                    read_head = readToAfterSpace(read_head, buffer);
                    try v_buffer.append(try parseFloat(real, &read_head, buffer));
                    // Y
                    read_head = readToAfterSpace(read_head, buffer);
                    try v_buffer.append(try parseFloat(real, &read_head, buffer));
                    // Z
                    read_head = readToAfterSpace(read_head, buffer);
                    try v_buffer.append(try parseFloat(real, &read_head, buffer));
                },
                't' => {
                    // S
                    read_head = readToAfterSpace(read_head, buffer);
                    try vt_buffer.append(try parseFloat(real, &read_head, buffer));
                    // T
                    read_head = readToAfterSpace(read_head, buffer);
                    try vt_buffer.append(try parseFloat(real, &read_head, buffer));
                },
                'n' => {
                    // NX
                    read_head = readToAfterSpace(read_head, buffer);
                    try vn_buffer.append(try parseFloat(real, &read_head, buffer));
                    // NY
                    read_head = readToAfterSpace(read_head, buffer);
                    try vn_buffer.append(try parseFloat(real, &read_head, buffer));
                    // NZ
                    read_head = readToAfterSpace(read_head, buffer);
                    try vn_buffer.append(try parseFloat(real, &read_head, buffer));
                },
                else => {
                    unreachable;
                },
                }
            },
            'f' => {
                // Parse face
                // Assumes trianglulated faces
                read_head += 1;
                read_head += 1;
                var i: usize = 0;
                while (i < 3) : (i += 1) {
                    // read_head = readToAfterSpace(read_head, buffer);
                    const v_id = ((try parseUInt(&read_head, buffer)) - 1) * 3;
                    read_head += 1;
                    const vt_id = ((try parseUInt(&read_head, buffer)) - 1) * 2;
                    read_head += 1;
                    const vn_id = ((try parseUInt(&read_head, buffer)) - 1) * 3;
                    read_head += 1;
                    const v = Vertex{
                        .x = v_buffer.at(v_id + 0),
                        .y = v_buffer.at(v_id + 1),
                        .z = v_buffer.at(v_id + 2),

                        .nx = vn_buffer.at(vn_id + 0),
                        .ny = vn_buffer.at(vn_id + 1),
                        .nz = vn_buffer.at(vn_id + 2),

                        .u = vt_buffer.at(vt_id + 0),
                        .v = vt_buffer.at(vt_id + 1),
                    };
                    try verticies.append(v);
                }
                read_head -= 1;
            },
            else => {
                continue;
            },
        }
    }
    return Mesh.createSimple(verticies.toSlice());
}
