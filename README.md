# NSXPCConnection Anonymous Listener Test

This repository contains a minimal Objective-C executable that verifies an in-process `NSXPCListener` created with `anonymousListener` can accept a connection and reply over an `NSXPCConnection`.

## What It Tests

The test performs a single request-response exchange:

- Creates an anonymous `NSXPCListener`
- Exports a simple `XPCEchoing` service implementation
- Connects to the listener through its endpoint
- Sends `"hello from objc"`
- Verifies the reply is `"HELLO FROM OBJC"`

If the listener never replies, the test fails after a 5 second timeout.

## Files

- `NSXPCConnectionAnonymousListenerTest.m`: the test program
- `run-test.sh`: builds the program with `clang` and runs it

## Requirements

- macOS
- Xcode command line tools
- Foundation framework available through the active macOS SDK

## Run The Test

From the repository root:

```sh
./run-test.sh
```

The script will:

1. Resolve the active macOS SDK with `xcrun`
2. Compile `NSXPCConnectionAnonymousListenerTest.m` with `clang`
3. Run the produced executable

## Expected Output

On success, the program prints:

```text
NSXPCConnection test passed: HELLO FROM OBJC
```

On failure, it exits non-zero and prints a timeout, proxy error, or unexpected reply message.

## Notes

- The test intentionally avoids GCD APIs such as `dispatch_semaphore_*` and `dispatch_time`.
- Waiting is implemented by pumping the current run loop until the reply arrives or the timeout expires.
- This matters because one of the non-Xcode build paths used with this repo does not automatically link `libdispatch`, which causes link failures when `dispatch_*` symbols are referenced.
