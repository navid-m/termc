const std = @import("std");
const builtin = @import("builtin");
const os = std.os;

const BOOL = os.windows.BOOL;
const DWORD = os.windows.DWORD;
const TRUE = os.windows.TRUE;
const FALSE = os.windows.FALSE;

const CtrlHandlerFn = *const fn (DWORD) callconv(.C) BOOL;
const SignalHandlerFn = *const fn (c_int) callconv(.C) void;

extern "c" fn signal(sig: c_int, handler: ?*const fn (c_int) callconv(.C) void) callconv(.C) ?*const fn (c_int) callconv(.C) void;
extern "kernel32" fn SetConsoleCtrlHandler(
    handler: ?CtrlHandlerFn,
    add: BOOL,
) BOOL;

/// Set up control key handler via Windows API
pub fn setupWindowsCtrlCHandler(handler: CtrlHandlerFn) !void {
    if (SetConsoleCtrlHandler(handler, TRUE) == FALSE) {}
}

/// Set up control key handler using available POSIX APIs
pub fn setupUnixCtrlCHandler(handler: SignalHandlerFn) !void {
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

/// Internal logic to retrieve user input from standard input stream
fn getBackOpt() ![]const u8 {
    return try std.io
        .getStdIn()
        .reader()
        .readUntilDelimiterOrEofAlloc(std.heap.page_allocator, '\n', 100) orelse return error.InputWasNull;
}

/// Get some input with a user-defined prompt
pub fn inputWithPrompt(prompt: []const u8) ![]const u8 {
    try std.io.getStdOut().writer().print("{s}", .{prompt});
    return std.mem.trim(u8, try getBackOpt(), "\n\r");
}

/// Get some user input
pub fn input() ![]const u8 {
    return std.mem.trim(u8, try getBackOpt(), "\n\r");
}

/// Print some text
pub fn print(text: []const u8) !void {
    try std.io.getStdOut().writer().print("{s}\n", .{text});
}

/// Format a string into a buffer and return the slice
///
/// Requires allocator
pub fn sprintf(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype, size: usize) ![]u8 {
    const buf = try allocator.alloc(u8, size);
    const result = std.fmt.bufPrint(buf, fmt, args) catch |err| {
        allocator.free(buf);
        return err;
    };
    return result;
}

/// Clear the terminal screen
pub fn clearScreen() !void {
    try std.io.getStdOut().writer().print("\x1b[2J\x1b[H", .{});
}

/// Prompt for an integer
///
/// Will error if invalid integer is input
pub fn inputInt(comptime T: type) !T {
    const txt = try input();
    return try std.fmt.parseInt(T, txt, 10);
}

/// Prompt for a float
///
/// Will error if invalid float is input
pub fn inputFloat(comptime T: type) !T {
    const txt = try input();
    return try std.fmt.parseFloat(T, txt);
}

/// Example CTRL handler - Windows
fn ctrlHandlerWindows(ctrl_type: DWORD) callconv(.C) BOOL {
    switch (ctrl_type) {
        0 => {
            std.debug.print("Caught Ctrl+C (Windows)\n", .{});
        },
        else => return FALSE,
    }
    return TRUE;
}

/// Example CTRL handler - POSIX
fn ctrlHandlerPosix(_: c_int) callconv(.C) void {
    std.debug.print("Captured it.", .{});
}

test {
    try print("Waiting for Ctrl+C...");

    if (builtin.os.tag == .windows) {
        try setupWindowsCtrlCHandler(ctrlHandlerWindows);
    } else {
        try setupUnixCtrlCHandler(ctrlHandlerPosix);
    }

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}
