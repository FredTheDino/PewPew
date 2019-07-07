pub const real = f32;

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
        const c: real = cos(angle);
        const s: real = sin(angle);
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
};

