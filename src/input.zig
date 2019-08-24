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
    SHOOT,
    RELOAD,
    DEBUG,
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
                        process(KeyEvent.create(0, Event.QUIT, 1));
                    },
                    SDL_WINDOWEVENT_SIZE_CHANGED, SDL_WINDOWEVENT_RESIZED =>
                        onResize(event.window.data1, event.window.data2),
                    else => {},
                }
            },
            SDL_KEYDOWN, SDL_KEYUP => {
                if (event.key.repeat != 0) continue;
                const key = event.key.keysym.sym;
                const is_down = event.key.state == SDL_PRESSED;
                const key_evet = KeyEvent.key(key, is_down);
                process(key_evet);
            },
            SDL_CONTROLLERBUTTONUP, SDL_CONTROLLERBUTTONDOWN => {
                const button = event.cbutton.button;
                const which = event.cbutton.which;
                const is_down = event.cbutton.state == SDL_PRESSED;
                if (button == SDL_CONTROLLER_BUTTON_A)
                    KeyEvent.addController(which);
                const key_evet = KeyEvent.button(which, button, is_down);
                process(key_evet);
            },
            SDL_CONTROLLERAXISMOTION => {
                // TODO: Other controllers need work, like the PS4
                // Game pad is actually 2 game pads, one for motion
                // and one for the normal stuff.
                if (@mod(event.caxis.which, 2) == 1) { continue; }
                const raw_motion = event.caxis.value;
                var motion = @intToFloat(f32, raw_motion) /
                             @intToFloat(f32, 0x7FFF);
                if (math.fabs(motion) < 0.05) {
                    motion = 0.0;
                }
                const axis = @intToEnum(SDL_GameControllerAxis, event.caxis.axis);
                const which = event.caxis.which;
                const key_evet = KeyEvent.axis(which, axis, motion);
                process(key_evet);
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
                KeyEvent.removeController(event.cdevice.which);
            },
            else => {
            },
        }
    }
}

const KeyEvent = struct {
    player: PlayerId,
    event: Event,
    value: f32,

    const NUM_PLAYERS = 4;
    var num_active_ctrls: u32 = 0;
    var player_to_controller: [NUM_PLAYERS]c_int = [_]c_int{0xFF, 0xFF, 0xFF, 0xFF};

    fn addController(controller_id: i32) void {
        assert(controller_id != 0xFF);
        if (num_active_ctrls == NUM_PLAYERS) return;
        // Don't allow duplicates
        for (player_to_controller) |ctrl| {
            if (controller_id == ctrl)
                return;
        }
        for (player_to_controller) |ctrl, i| {
            if (ctrl != 0xFF)
                continue;
            player_to_controller[i] = controller_id;
            num_active_ctrls += 1;
            return;
        }
    }

    fn controllerToPlayer(c: c_int) !PlayerId {
        for (player_to_controller) |ctrl, i| {
            if (c == ctrl)
                return @intCast(PlayerId, i);
        }
        return error.NotMappedController;
    }

    fn removeController(controller_id: c_int) void {
        for (player_to_controller) |ctrl, i| {
            if (controller_id != ctrl)
                continue;
            player_to_controller[i] = 0xFF;
            return;
        }
    }

    fn create(player: PlayerId, event: Event, v: f32) KeyEvent {
        return KeyEvent{
            .player = player,
            .event = event,
            .value = v,
        };
    }

    pub fn button(which: c_int, b: c_int, is_down: bool) KeyEvent {
        const player = controllerToPlayer(which)
                    catch return create(0, Event.NO_INPUT_EVENT, 0.0);
        // TODO: Support directional buttons???
        const event = switch (b) {
            SDL_CONTROLLER_BUTTON_A => Event.JUMP,
            SDL_CONTROLLER_BUTTON_B => Event.RELOAD,
            SDL_CONTROLLER_BUTTON_RIGHTSHOULDER => Event.SHOOT,
            else => Event.NO_INPUT_EVENT,
        };
        var value_input: f32 = undefined;
        switch(is_down) {
            true => { value_input = 1.0; },
            false => { value_input = 0.0; },
        }
        return create(player, event, value_input);
    }

    pub fn axis(which: c_int, a: SDL_GameControllerAxis, motion: f32) KeyEvent {
        const player = controllerToPlayer(which)
                    catch return create(0, Event.NO_INPUT_EVENT, 0.0);
        const event = switch(a) {
            SDLA_LEFTX => Event.MOVE_X,
            SDLA_LEFTY => Event.MOVE_Y,
            SDLA_RIGHTX => Event.LOOK_X,
            SDLA_RIGHTY => Event.LOOK_Y,
            else => Event.NO_INPUT_EVENT,
        };
        return create(player, event, motion);
    }

    pub fn key(k: c_int, is_down: bool) KeyEvent {
        var event = switch(k) {
            SDLK_x => create(0, Event.DEBUG,   1.0),
            SDLK_d => create(0, Event.MOVE_X,  1.0),
            SDLK_a => create(0, Event.MOVE_X, -1.0),
            SDLK_w => create(0, Event.MOVE_Y, -1.0),
            SDLK_s => create(0, Event.MOVE_Y,  1.0),
            SDLK_1 => create(0, Event.LOOK_Y, -1.0),
            SDLK_2 => create(0, Event.LOOK_Y,  1.0),
            SDLK_e => create(0, Event.LOOK_X,  1.0),
            SDLK_q => create(0, Event.LOOK_X, -1.0),
            SDLK_ESCAPE => create(0, Event.QUIT, 1.0),
            else => create(0, Event.NO_INPUT_EVENT, 0.0),
        };
        if (!is_down)
            event.value = 0.0;
        return event;
    }
};

fn process(key_event: KeyEvent) void {
    if (key_event.event == Event.NO_INPUT_EVENT) return;
    const hash = hashEvent(key_event.player, key_event.event);
    states[hash].process(key_event.value);
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

