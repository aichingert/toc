const std = @import("std");
const rl = @import("raylib");
const mg = @import("mongoose");
const packets = @import("packets");

const Thread = std.Thread;
const Mutex = Thread.Mutex;

const server = "ws://pattern.nitoa.at/websocket";

pub var tasks = Tasks.init();
pub var colors: [81]rl.Color = [_]rl.Color{rl.Color.white} ** 81;
const players: [2]rl.Color = [_]rl.Color{ rl.Color.blue, rl.Color.orange };

pub const Tasks = struct {
    mutex: Mutex,
    position: i32,
    i: usize,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .position = -1,
            .i = 0,
            .mutex = Mutex{},
        };
    }

    pub fn setPosition(self: *Self, pos: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.position = pos;
    }

    pub fn getPosition(self: *Self) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const value = self.position;
        self.position = -1;
        return value;
    }
};

fn event_handler(
    c: ?*mg.MgConnection,
    event: c_int,
    event_data: ?*anyopaque,
) callconv(.C) void {
    // TODO: check that ws connection was successful if (event == mg.MG_EV_WS_OPEN) {

    if (event == mg.Event.ws_msg) {
        if (event_data) |data| {
            const wm = @as(*mg.WsMessage, @ptrCast(@alignCast(data)));

            if (std.fmt.parseInt(usize, std.mem.span(wm.data.buf[5..]), 10)) |idx| {
                colors[idx] = players[tasks.i];
                tasks.i = 1 - tasks.i;
            } else |err| {
                std.debug.print("{?}\n", .{err});
            }
        }
    }

    const position = tasks.getPosition();

    if (position != -1) {
        const str = (packets.Set{ .idx = position }).encode();

        //mg.WEBSOCKET_OP_TEXT = 1,
        if (mg.toConnection(c)) |conn| {
            conn.wsSend(@as(?*const anyopaque, @ptrCast(str)), str.len, 1);
        }
    }
}

pub fn init() void {
    var event_mgr = mg.Manager{};
    mg.mgrInit(&event_mgr);
    var is_done = false;

    const conn = mg.Connection.toWs(
        &event_mgr,
        server,
        event_handler,
        &is_done,
        null,
    );

    while (conn != null and !is_done) mg.mgrPoll(&event_mgr);
}