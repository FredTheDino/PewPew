use @import("import.zig");
const warn = @import("std").debug.warn;

pub const Event = enum {
    NO_INPUT_EVENT,
    QUIT,
    MOVE_X,
    MOVE_Y,

    LOOK_Y,
    LOOK_X,

    JUMP,
};

fn hashEvent(player: PlayerId, event: Event) usize {
    return @intCast(usize, player) |
        @shlExact(@intCast(usize, @enumToInt(event)), NUM_PLAYER_ID_BITS);
}

const State = enum(u2) {
    PRESSED  = 0b11,
    DOWN     = 0b01,
    RELEASED = 0b10,
    UP       = 0b00,

    pub fn update(state: State) State {
        return @intToEnum(State, @enumToInt(state) & 0b01);
    }

    pub fn isDown(self: State) bool {
        return (@enumToInt(self) & 0b01) != 0;
    }
};

pub const Action = struct {
    state: State,
    value: f32,

    pub fn isMe(self: Action, other: u4) bool {
        return self.owner & other != 0;
    }

    pub fn down(self: Action) bool {
        return (@enumToInt(self.state) & @enumToInt(State.DOWN)) != 0;
    }

    pub fn up(self: Action) bool {
        return (self.state & State.UP) != 0;
    }

    pub fn released(self: Action) bool {
        return self.state == State.RELEASED;
    }

    pub fn pressed(self: Action) bool {
        return self.state == State.PRESSED;
    }

    pub fn process(self: *Action, val: f32) void {
        self.value = val;
        const press = val != 0.0;
        if (self.state.isDown() != press) {
            self.state = switch(press) {
                true => State.PRESSED,
                false => State.RELEASED,
            };
        }
    }

    pub fn update(self: *Action) void {
        self.state = self.state.update();
    }
};

var controllers: []*Controller = []*Controller{undefined} ** 4;

pub fn numPlayers() u32 {
    var num: u32 = 0;
    for (controllers) |p| {
        num += @boolToInt(p != undefined);
    }
    return num;
}

// TODO: Could store one field less.
var onResize: fn(i32, i32) void = undefined;
// TODO: Zero this out
var states: [@memberCount(Event) * 4]Action = undefined;

fn keyToEvent(k: c_int) Event {
    // TODO:
    return switch(k) {
        SDLK_ESCAPE => Event.QUIT,
        else => Event.NO_INPUT_EVENT,
    };
}

fn keyToPlayer(k: c_int) PlayerId {
    return 0;
}

fn buttonToEvent(b: c_int) Event {
    return switch (b) {
        SDL_CONTROLLER_BUTTON_A => Event.JUMP,
        else => Event.NO_INPUT_EVENT,
    };
}

fn axisToEvent(a: SDL_GameControllerAxis) Event {
    return switch(a) {
        SDLA_LEFTX => Event.MOVE_X,
        SDLA_LEFTY => Event.MOVE_Y,
        SDLA_RIGHTX => Event.LOOK_X,
        SDLA_RIGHTY => Event.LOOK_Y,
        else => Event.NO_INPUT_EVENT,
    };
}

fn controllerToPlayer(c: c_int) PlayerId {
    return @intCast(PlayerId, c);
}

pub fn update() void {
    for (states) |*state| {
        state.update();
    }

    var event: SDL_Event = undefined;
    while (SDL_PollEvent(&event) != 0) {
        switch(event.type) {
            SDL_WINDOWEVENT => {
                switch (event.window.event) {
                    SDL_WINDOWEVENT_CLOSE => {
                        process(0, Event.QUIT, 1);
                        process(0, Event.QUIT, 0);
                    },
                    SDL_WINDOWEVENT_SIZE_CHANGED, SDL_WINDOWEVENT_RESIZED =>
                        onResize(event.window.data1, event.window.data2),
                    else => {},
                }
            },
            SDL_KEYDOWN => {
                if (event.key.repeat != 0) continue;
                if (event.key.repeat != 0) continue;
                const key = event.key.keysym.sym;
                process(keyToPlayer(key), keyToEvent(key), 1);
            },
            SDL_KEYUP => {
                if (event.key.repeat != 0) continue;
                const key = event.key.keysym.sym;
                process(keyToPlayer(key), keyToEvent(key), 0);
            },
            SDL_CONTROLLERBUTTONDOWN => {
                const button = event.cbutton.button;
                const which = event.cbutton.which;
                process(controllerToPlayer(which), buttonToEvent(button), 1);
            },
            SDL_CONTROLLERBUTTONUP => {
                const button = event.cbutton.button;
                const which = event.cbutton.which;
                process(controllerToPlayer(which), buttonToEvent(button), 0);
            },
            SDL_CONTROLLERAXISMOTION => {
                // TODO: Other controllers need work, like the PS4
                // Game pad is actually 2 game pads, one for motion
                // and one for the normal stuff.
                if (event.caxis.which != 0) { continue; }
                const raw_motion = event.caxis.value;
                var motion = @intToFloat(f32, raw_motion) /
                             @intToFloat(f32, 0x7FFF);
                if (math.fabs(motion) < 0.05) {
                    motion = 0.0;
                }
                const axis = @intToEnum(SDL_GameControllerAxis, event.caxis.axis);
                const which = event.caxis.which;
                process(controllerToPlayer(which), axisToEvent(axis), motion);
            },
            SDL_JOYDEVICEADDED => {
                var i: c_int = 0;
                while (i < SDL_NumJoysticks()): (i += 1) {
                    if (@enumToInt(SDL_IsGameController(i)) == 1) {
                        _ = SDL_GameControllerOpen(i);
                        std.debug.warn("Connected Controller: {}\n", i);
                    }
                }
            },
            SDL_JOYDEVICEREMOVED => {
            },
            else => {
            },
        }
    }
}

fn process(player: PlayerId, event: Event, v: f32) void {
    if (event == Event.NO_INPUT_EVENT) { return; }
    const hash = hashEvent(player, event);
    states[hash].process(v);
}

pub fn down(player: u2, event: Event) bool {
    return states[hashEvent(player, event)].down();
}

pub fn up(player: u2, event: Event) bool {
    return states[hashEvent(player, event)].up();
}

pub fn released(player: u2, event: Event) bool {
    return states[hashEvent(player, event)].released();
}

pub fn pressed(player: u2, event: Event) bool {
    return states[hashEvent(player, event)].pressed();
}

pub fn value(player: u2, event: Event) f32 {
    return states[hashEvent(player, event)].value;
}

