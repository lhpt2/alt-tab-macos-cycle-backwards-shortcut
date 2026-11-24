import ApplicationServices
import Darwin

/// Fronting ONE window through the WindowServer, the way AltTab and yabai do. Activating the app instead
/// (AX "frontmost", `NSRunningApplication.activate`) brings the app forward on the Space it was last active
/// on, so with windows on several Spaces macOS jumps to that Space rather than staying with the chosen window.
/// The functions are private, so they are looked up at runtime: if a macOS update removes them,
/// `isAvailable` turns false and the caller falls back to app activation.
enum WindowServer {
    private typealias SetFrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    private typealias ProcessForPid = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let setFrontProcess: SetFrontProcess? = symbol(skyLight, "_SLPSSetFrontProcessWithOptions")
    private static let postEventRecord: PostEventRecord? = symbol(skyLight, "SLPSPostEventRecordTo")
    private static let processForPid: ProcessForPid? = symbol(UnsafeMutableRawPointer(bitPattern: -2), "GetProcessForPID") // RTLD_DEFAULT
    /// `kCPSUserGenerated`: the switch counts as the user's, and only the given window comes forward.
    private static let userGenerated: UInt32 = 0x200

    static var isAvailable: Bool { setFrontProcess != nil && postEventRecord != nil && processForPid != nil }

    /// Fronts the window's process with only that window, then makes it key. A window on another Space makes
    /// macOS switch to that Space.
    static func focus(pid: pid_t, windowId: CGWindowID) {
        guard let setFrontProcess, let postEventRecord, let processForPid else { return }
        var psn = ProcessSerialNumber()
        guard processForPid(pid, &psn) == noErr else { return }
        _ = setFrontProcess(&psn, windowId, userGenerated)
        makeKey(&psn, windowId, postEventRecord)
    }

    /// A synthetic mouse down and up aimed far outside the window: it becomes key without anything inside it
    /// being clicked. Record layout from AltTab (`WindowFocusEvent`); the buffer is longer than the declared
    /// 0xf8 bytes because WindowServer on macOS 14.7.4+ can read past it.
    private static func makeKey(_ psn: inout ProcessSerialNumber, _ windowId: CGWindowID, _ post: PostEventRecord) {
        var windowId = windowId
        var point = CGPoint(x: 300_000, y: 300_000)
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0x04] = 0xF8
        bytes[0x3A] = 0x10
        memcpy(&bytes[0x10], &point, MemoryLayout<CGPoint>.size)
        memcpy(&bytes[0x20], &point, MemoryLayout<CGPoint>.size)
        memcpy(&bytes[0x3C], &windowId, MemoryLayout<CGWindowID>.size)
        bytes.withUnsafeMutableBufferPointer { buffer in
            let pointer = buffer.baseAddress!
            pointer[0x08] = 0x01
            _ = post(&psn, pointer)
            pointer[0x08] = 0x02
            _ = post(&psn, pointer)
        }
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}
