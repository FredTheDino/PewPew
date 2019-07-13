use @import("import.zig");
const warn = @import("std").debug.warn;

pub const Input = struct {
    should_close: bool,

    pub fn InputHandler(comptime Keys: type) type {
        return struct {
            const Self = @This();
            
            const State = enum(u2) {
                PRESSED  = 0b11,
                DOWN     = 0b01,
                RELEASED = 0b10,
                UP       = 0b00,

                pub fn update(state: State) State {
                    return @intToEnum(State, @enumToInt(state) & 0b01);
                }

                pub fn isSameState(self: State, other: State) bool {
                    return (@enumToInt(self) & 0b01) == (@enumToInt(other) & 0b01);
                }
            };

            // TODO: Could store one field less.
            states: [@memberCount(Keys)]State,

            pub fn update(self: *Self) void {
                for (self.states) |state, i| {
                    self.states[i] = state.update();
                }

                var event: SDL_Event = undefined;
                while (SDL_PollEvent(&event) != 0) {
                    if (event.type == SDL_WINDOWEVENT) {
                        if (event.window.event == SDL_WINDOWEVENT_CLOSE) {
                            self.states[@enumToInt(Keys.QUIT)] = State.PRESSED;
                        }
                    } else if (event.type == SDL_KEYDOWN) {
                        if (event.key.repeat != 0) continue;
                        self.process(event.key.keysym.sym, State.PRESSED);
                    } else if (event.type == SDL_KEYUP) {
                        if (event.key.repeat != 0) continue;
                        self.process(event.key.keysym.sym, State.RELEASED);
                    }
                }
            }
            
            pub fn process(self: *Self, key: i32, state: State) void {
                const event = Keys.map(key);
                if (event == Keys.NONE)
                    return;
                const current = self.states[@enumToInt(event)];
                if (!current.isSameState(state)) {
                   self.states[@enumToInt(event)] = state; 
                }
            }

            pub fn isDown(self: Self, key: Keys) bool {
                return self.states[@enumToInt(key)].isSameState(State.DOWN);
            }
        };
    }
};

