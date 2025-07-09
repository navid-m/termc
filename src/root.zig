const std = @import("std");
const os = std.os;
const builtin = @import("builtin");

const BOOL = os.windows.BOOL;
const DWORD = os.windows.DWORD;
const TRUE = os.windows.TRUE;
const FALSE = os.windows.FALSE;
const CtrlHandlerFn = *const fn (DWORD) callconv(.C) BOOL;

extern "c" fn signal(sig: c_int, handler: ?*const fn (c_int) callconv(.C) void) callconv(.C) ?*const fn (c_int) callconv(.C) void;

extern "kernel32" fn SetConsoleCtrlHandler(
    handler: ?CtrlHandlerFn,
    add: BOOL,
) BOOL;

pub fn setupWindowsHandler(handler: CtrlHandlerFn) !void {
    if (SetConsoleCtrlHandler(handler, TRUE) == FALSE) {}
}

const SignalHandlerFn = *const fn (c_int) callconv(.C) void;

pub fn setupUnixHandler(handler: SignalHandlerFn) !void {
    if (builtin.os.tag == .linux) {
        var act: os.linux.Sigaction = std.mem.zeroes(os.linux.Sigaction);
        act.handler = .{ .handler = handler };
        act.mask = std.mem.zeroes(os.linux.sigset_t);
        act.flags = 0;
        if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {}
    } else {
        if (signal(os.plan9.SIG.INT, handler) == null) {}
    }
}

fn ctrlHandlerWindows(ctrl_type: DWORD) callconv(.C) BOOL {
    switch (ctrl_type) {
        0 => {
            std.debug.print("Caught Ctrl+C (Windows)\n", .{});
        },
        else => return FALSE,
    }
    return TRUE;
}

test {
    std.debug.print("Waiting for Ctrl+C...\n", .{});

    if (builtin.os.tag == .windows) {
        try setupWindowsHandler(ctrlHandlerWindows);
    } else {
        try setupUnixHandler();
    }

    while (true) {
        std.time.sleep(1_000_000_000);
    }
}
