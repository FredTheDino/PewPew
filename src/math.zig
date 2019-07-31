// TODO: Make this into SIMD instructions.
const assert = @import("std").debug.assert;

pub const real = f32;
pub const accuracy = 0.0001;

pub const math = @import("std").math;

pub fn sign(v: var) @typeOf(v) {
    if (v < 0)
        return -1;
    return 1;
}

pub fn V2(x: real, y: real) Vec2 {
    return Vec2 {
        .x = x,
        .y = y,
    };
}

pub fn V3(x: real, y: real, z: real) Vec3 {
    return Vec3 {
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn V4(x: real, y: real, z: real, w: real) Vec4 {
    return Vec4 {
        .x = x,
        .y = y,
        .z = z,
        .w = w,
    };
}

pub fn M4(a: real, b: real, c: real, d: real,
          e: real, f: real, g: real, h: real,
          i: real, j: real, k: real, l: real,
          m: real, n: real, o: real, p: real) Mat4 {
    var mat: Mat4 = undefined;
    mat.v[0][0] = a;
    mat.v[0][1] = b;
    mat.v[0][2] = c;
    mat.v[0][3] = d;
    mat.v[1][0] = e;
    mat.v[1][1] = f;
    mat.v[1][2] = g;
    mat.v[1][3] = h;
    mat.v[2][0] = i;
    mat.v[2][1] = j;
    mat.v[2][2] = k;
    mat.v[2][3] = l;
    mat.v[3][0] = m;
    mat.v[3][1] = n;
    mat.v[3][2] = o;
    mat.v[3][3] = p;
    return mat;
}

pub fn AA(v: Vec3, angle: real) Quat {
    const half_angle = angle / 2.0;
    return Quat{
        .v = v.normalized().scale(math.sin(half_angle)),
        .w = math.cos(half_angle),
    };
}


pub fn H(x: real, y: real, z: real, w: real) Quat {
    return Quat{
        .v = Vec3{
            .x = x,
            .y = y,
            .z = z,
        },
        .w = w,
    };
}

// NOTE: Cannot be uploaded to OpenGL directly,
// since it's not packed!!!!
pub const Quat = struct {
    v: Vec3,
    w: real,

    pub fn identity() Quat {
        return H(0, 0, 0, 1);
    }

    pub fn byVector(a: Quat, v: Vec3, delta: f32) Quat {
        const half_delta = delta / 2;
        const b = H(v.x, v.y, v.z, 0);
        return a.add(b.mul(a).scale(half_delta)).normalized();
    }

    pub fn add(a: Quat, b: Quat) Quat {
        return Quat{
            .v = a.v.add(b.v),
            .w = a.w + b.w,
        };
    }

    pub fn mul(a: Quat, b: Quat) Quat {
        return Quat{
            // v x v' + w' v + w v'
            .v = a.v.cross(b.v).add(b.v.scale(a.w)).add(a.v.scale(b.w)),
            .w = a.w * b.w - a.v.dot(b.v),
        };
    }

    pub fn scale(a: Quat, b: real) Quat {
        return Quat{
            .v = a.v.scale(b),
            .w = a.w * b,
        };
    }

    pub fn lengthSq(a: Quat) real {
        return a.w * a.w + a.v.lengthSq();
    }

    pub fn length(a: Quat) real {
        return @sqrt(real, @inlineCall(lengthSq, a));
    }

    pub fn fastNormalized(a: Quat) Quat {
        // Inaccurate when |a| is far from 1.0.
        return a.scale(1.0 / a.lengthSq());
    }

    pub fn normalized(a: Quat) Quat {
        return a.scale(1.0 / a.length());
    }

    pub fn neg(a: Quat) Quat {
        return Quat{
            .v = a.v.neg(), // Only flip vector part
            .w = a.w,
        };
    }

    pub fn toMat(in: Quat) Mat4 {
        // TODO: This might be a good idea, it goes into here for now...
        const l_sq = in.lengthSq();
        const d = math.fabs(l_sq - 1);
        var q: Quat = undefined;
        if (l_sq == 0.0) {
            return Mat4.identity();
        } if (d < 0.01) {
            q = in;
        } else if (d < 0.5) {
            q = in.fastNormalized();
        } else {
            q = in.normalized();
        }
        const w = q.w;
        const x = q.v.x;
        const y = q.v.y;
        const z = q.v.z;
        const result = M4(1 - 2 * (y * y + z * z),
                  2 * (x * y - w * z),
                  2 * (x * z + w * y), 0,

                  2 * (x * y + w * z),
                  1 - 2 * (x * x + z * z),
                  2 * (y * z - w * x), 0,

                  2 * (x * z - w * y),
                  2 * (y * z + w * x),
                  1 - 2 * (x * x + y * y), 0,

                  0, 0, 0, 1);
        return result;
    }
};

pub const Mat4 = packed struct {
    v: [4][4]real,

    pub fn identity() Mat4 {
        return M4(1, 0, 0, 0,
                  0, 1, 0, 0,
                  0, 0, 1, 0,
                  0, 0, 0, 1);
    }

    pub fn perspective(fov: f32, aspect_ratio: f32) Mat4 {
        const f = 100.0; // Far clipping plane
        const n = 1.0; // Near clipping plane
        const t = math.tan(fov * (math.pi / 180.0) / 2.0);
        const s = n / t;

        var out = identity();

        out.v[0][0] = s;
        out.v[1][1] = s * aspect_ratio;
        // -normalization
        out.v[2][2] = -f / (f - n);
        // Perspective
        out.v[3][2] = -f * n / (f - n);
        // Translation
        out.v[2][3] = -1;
        out.v[3][3] = 0;

        return out;
    }

    pub fn rotation(x: real, y: real, z: real) Mat4 {
        var z_matrix = identity();
        if (z != 0) {
            const sin_z = math.sin(z);
            const cos_z = math.cos(z);
            z_matrix.v[0][0] =  cos_z;
            z_matrix.v[0][1] = -sin_z;
            z_matrix.v[1][0] =  sin_z;
            z_matrix.v[1][1] =  cos_z;
        }

        var y_matrix = identity();
        if (y != 0) {
            const sin_y = math.sin(y);
            const cos_y = math.cos(y);
            y_matrix.v[0][0] =  cos_y;
            y_matrix.v[0][2] = -sin_y;
            y_matrix.v[2][0] =  sin_y;
            y_matrix.v[2][2] =  cos_y;
        }

        var x_matrix = identity();
        if (x != 0) {
            const sin_x = math.sin(x);
            const cos_x = math.cos(x);
            x_matrix.v[1][1] =  cos_x;
            x_matrix.v[1][2] = -sin_x;
            x_matrix.v[2][1] =  sin_x;
            x_matrix.v[2][2] =  cos_x;
        }
        return x_matrix.mulMat(y_matrix.mulMat(z_matrix));
    }

    pub fn scale(x: f32, y: f32, z: f32) Mat4 {
        return M4(x, 0, 0, 0,
                  0, y, 0, 0,
                  0, 0, z, 0,
                  0, 0, 0, 1);
    }

    pub fn translation(movement: Vec3) Mat4 {
        var out = identity();
        out.v[0][3] = movement.x;
        out.v[1][3] = movement.y;
        out.v[2][3] = movement.z;
        return out;
    }

    pub fn zero() Mat4 {
        return M4(0, 0, 0, 0,
                  0, 0, 0, 0,
                  0, 0, 0, 0,
                  0, 0, 0, 0);
    }

    pub fn mulMat(self: Mat4, other: Mat4) Mat4 {
        var out: Mat4 = zero();

        const indicies = []u32{0, 1, 2, 3};
        inline for (indicies) |row| {
            inline for (indicies) |col| {
                inline for (indicies) |i| {
                    out.v[row][col] += self.v[row][i] * other.v[i][col];
                }
            }
        }
        return out;
    }

    pub fn mulVec(self: Mat4, other: Vec4) Vec4 {
        const in = []real {other.x, other.y, other.z, other.w};
        var out = []real {0, 0, 0, 0};

        const indicies = []u32{0, 1, 2, 3};
        inline for (indicies) |row| {
            inline for (indicies) |i| {
                out[row] += self.v[i][row] * in[i];
            }
        }
        return V4(out[0], out[1], out[2], out[3]);
    }

    pub fn transpose(self: Mat4) Mat4 {
        var out: Mat4 = zero();

        const indicies = []u32{0, 1, 2, 3};
        inline for (indicies) |row| {
            inline for (indicies) |col| {
                out.v[row][col] = self.v[col][row];
            }
        }
        return out;
    }

    pub fn equalsAcc(self: Mat4, other: Mat4, acc: real) bool {
        const indicies = []u32{0, 1, 2, 3};
        inline for (indicies) |row| {
            inline for (indicies) |col| {
                if (math.fabs(self.v[row][col] - other.v[row][col]) > acc) {
                    return false;
                }
            }
        }
        return true;
    }

    pub fn equals(self: Mat4, other: Mat4) bool {
        return @inlineCall(equalsAcc, self, other, accuracy);
    }

    pub fn gfxDump(self: Mat4) void {
        const line = @import("graphics.zig").DebugDraw.gfx_util.line;
        const o = V3(self.v[0][3], self.v[1][3], self.v[2][3]);
        const x = V3(self.v[0][0], self.v[1][0], self.v[2][0]).add(o);
        const y = V3(self.v[0][1], self.v[1][1], self.v[2][1]).add(o);
        const z = V3(self.v[0][2], self.v[1][2], self.v[2][2]).add(o);
        line(o, x, V3(1, 0, 0));
        line(o, y, V3(0, 1, 0));
        line(o, z, V3(0, 0, 1));
        line(o, V3(0, 0, 0), V3(1, 1, 1));
    }

    pub fn dump(self: Mat4) void {
        const warn = @import("std").debug.warn;
        warn("\n");
        for (self.v) |row| {
            for (row) |cell| {
                warn("{}, ", cell);
            }
            warn("\n");
        }
    }
};

test "Mat4" {
    const warn = @import("std").debug.warn;
    var a = Mat4.identity();
    var b = Mat4.identity();
    var c = a.mul(b);
    assert(c.equals(Mat4.identity()));

    a = Mat4.zero();
    c = a.mulMat(b);
    assert(c.equals(Mat4.zero()));

    a = M4(0, 1, 0, 0,
           1, 0, 0, 0,
           0, 0, 1, 0,
           0, 0, 0, 0);
    b = M4(1, 0, 1, 0,
           1, 1, 0, 0,
           0, 1, 1, 0,
           0, 0, 0, 0);

    c = a.mulMat(b);
    assert(c.equals(M4(1, 1, 0, 0,
                       1, 0, 1, 0,
                       0, 1, 1, 0,
                       0, 0, 0, 0)));
    c = b.mulMat(a);
    assert(c.equals(M4(0, 1, 1, 0,
                       1, 1, 0, 0,
                       1, 0, 1, 0,
                       0, 0, 0, 0)));

    var p = V4(1, 2, 3, 1);
    assert(a.mulVec(p).equals(V4(2, 1, 3, 0)));
}

pub const Vec2 = packed struct {
    x : real,
    y : real,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2 {
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn neg(self: Vec2) Vec2 {
        return Vec2 {
            .x = -self.x,
            .y = -self.y,
        };
    }

    pub fn scale(self: Vec2, s: real) Vec2 {
        return Vec2 {
            .x = self.x * s,
            .y = self.y * s,
        };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return Vec2 {
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return self.add(other.neg());
    }

    pub fn dot(self: Vec2, other: Vec2) real {
        return self.x * other.x + self.y * other.y;
    }

    pub fn rotate(self: Vec2, angle: real) Vec2 {
        const c: real = math.cos(angle);
        const s: real = math.sin(angle);
        return Vec2 {
            .x = c * self.x - s * self.y,
            .y = s * self.x + c * self.y,
        };
    }

    pub fn ccw(self: Vec2) Vec2 {
        return Vec2 {
            .x = -self.y,
            .y =  self.x,
        };
    }

    pub fn lengthSq(self: Vec2) real {
        return @inlineCall(dot, self, self);
    }

    pub fn length(self: Vec2) real {
        return @sqrt(real, @inlineCall(lengthSq, self));
    }

    pub fn normalized(self: Vec2) Vec2 {
        const l = self.length();
        if (l == 0.0) return self;
        return self.scale(1.0 / l);
    }

    pub fn equalsAcc(self: Vec2, other: Vec2, acc: real) bool {
        return math.fabs(self.x - other.x) < acc and
               math.fabs(self.y - other.y) < acc;
    }

    pub fn equals(self: Vec2, other: Vec2) bool {
        return @inlineCall(equalsAcc, self, other, accuracy);
    }
};

pub const Vec3 = packed struct {
    x : real,
    y : real,
    z : real,

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3 {
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn neg(self: Vec3) Vec3 {
        return Vec3 {
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn scale(self: Vec3, s: real) Vec3 {
        return Vec3 {
            .x = self.x * s,
            .y = self.y * s,
            .z = self.z * s,
        };
    }

    pub fn mul(self: Vec3, other: Vec3) Vec3 {
        return Vec3 {
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
        };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return self.add(other.neg());
    }

    pub fn dot(self: Vec3, other: Vec3) real {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn rotateZ(self: Vec3, angle: real) Vec3 {
        const c: real = math.cos(angle);
        const s: real = math.sin(angle);
        return Vec3 {
            .x = c * self.x - s * self.y,
            .y = s * self.x + c * self.y,
            .z = self.z,
        };
    }

    pub fn rotateY(self: Vec3, angle: real) Vec3 {
        const c: real = math.cos(angle);
        const s: real = math.sin(angle);
        return Vec3 {
            .x = c * self.x - s * self.z,
            .y = self.y,
            .z = s * self.x + c * self.z,
        };
    }

    pub fn rotateX(self: Vec3, angle: real) Vec3 {
        const c: real = math.cos(angle);
        const s: real = math.sin(angle);
        return Vec3 {
            .x = self.x,
            .y = c * self.y - s * self.z,
            .z = s * self.y + c * self.z,
        };
    }

    pub fn hadamard(a: Vec3, b: Vec3) Vec3 {
        return V3(a.x * b.x,
                  a.y * b.y,
                  a.z * b.z);
    }

    pub fn lengthSq(self: Vec3) real {
        return @inlineCall(dot, self, self);
    }

    pub fn length(self: Vec3) real {
        return @sqrt(real, @inlineCall(lengthSq, self));
    }

    pub fn normalized(self: Vec3) Vec3 {
        const l = self.length();
        if (l == 0.0) return self;
        return self.scale(1.0 / l);
    }

    pub fn equalsAcc(self: Vec3, other: Vec3, acc: real) bool {
        return math.fabs(self.x - other.x) < acc and
               math.fabs(self.y - other.y) < acc and
               math.fabs(self.z - other.z) < acc;
    }

    pub fn equals(self: Vec3, other: Vec3) bool {
        return @inlineCall(equalsAcc, self, other, accuracy);
    }

    pub fn abs(self: Vec3) Vec3 {
        return V3(math.fabs(self.x),
                  math.fabs(self.y),
                  math.fabs(self.z));
    }

    pub fn toV4(self: Vec3, w: real) Vec4 {
        return V4(self.x, self.y, self.z, w);
    }
};

pub const Vec4 = packed struct {
    x : real,
    y : real,
    z : real,
    w : real,

    pub fn add(self: Vec4, other: Vec4) Vec4 {
        return Vec4 {
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
            .w = self.w + other.w,
        };
    }

    pub fn neg(self: Vec4) Vec4 {
        return Vec4 {
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
            .w = -self.w,
        };
    }

    pub fn scale(self: Vec4, s: real) Vec4 {
        return Vec4 {
            .x = self.x * s,
            .y = self.y * s,
            .z = self.z * s,
            .w = self.w * s,
        };
    }

    pub fn mul(self: Vec4, other: Vec4) Vec4 {
        return Vec4 {
            .x = self.x * other.x,
            .y = self.y * other.y,
            .z = self.z * other.z,
            .w = self.w * other.w,
        };
    }

    pub fn sub(self: Vec4, other: Vec4) Vec4 {
        return self.add(other.neg());
    }

    pub fn dot(self: Vec4, other: Vec4) real {
        return self.x * other.x + self.y * other.y +
               self.z * other.z + self.w + other.w;
    }

    pub fn lengthSq(self: Vec4) real {
        return @inlineCall(dot, self, self);
    }

    pub fn length(self: Vec4) real {
        return @sqrt(real, @inlineCall(lengthSq, self));
    }

    pub fn normalized(self: Vec4) Vec4 {
        const l = self.length();
        if (l == 0.0) return self;
        return self.scale(1.0 / l);
    }

    pub fn equalsAcc(self: Vec4, other: Vec4, acc: real) bool {
        return math.fabs(self.x - other.x) < acc and
               math.fabs(self.y - other.y) < acc and
               math.fabs(self.z - other.z) < acc;
    }

    pub fn equals(self: Vec4, other: Vec4) bool {
        return @inlineCall(equalsAcc, self, other, accuracy);
    }

    pub fn toV3(self: Vec4) Vec3 {
        return V3(self.x, self.y, self.z);
    }
};



// TODO: Probably write more tests for the math.
test "Vec2 basics" {
    {
    const a = V2(2, 0);
    assert(a.equals(Vec2 { .x = 2, .y = 0 }));
    {
        var b = a.rotate(math.pi);
        assert(b.equals(Vec2 { .x = -2, .y = 0 }));
    }
    {
        var b = a.rotate(math.pi / 2.0);
        assert(b.equals(Vec2 { .x = 0, .y = 2 }));
    }
    {
        var b = a.sub(V2(1, 1));
        assert(b.equals(Vec2 { .x = 1, .y = -1 }));
    }
    {
        var b = a.normalized();
        assert(b.equals(Vec2 { .x = 1, .y = 0 }));
    }
    }
}
