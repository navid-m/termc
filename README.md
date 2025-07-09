Simple package because this isn't in the stdlib for some idiotic reason.

Install:

```sh
zig fetch --save "git+https://github.com/navid-m/termc"
```

Usage:

```zig
fn ctrlHandlerWindows(ctrl_type: DWORD) callconv(.C) BOOL {
    switch (ctrl_type) {
        0 => {
            std.debug.print("Caught Ctrl+C (Windows)\n", .{});
        },
        else => return FALSE,
    }
    return TRUE;
}

fn ctrlHandlerPosix(_: c_int) callconv(.C) void {
    std.debug.print("Captured it.", .{});
}

test {
    std.debug.print("Waiting for Ctrl+C...\n", .{});

    if (builtin.os.tag == .windows) {
        try setupWindowsHandler(ctrlHandlerWindows);
    } else {
        try setupUnixHandler(ctrlHandlerPosix);
    }

    while (true) {
        std.time.sleep(1_000_000_000);
    }
}
```
