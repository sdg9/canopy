// TCC wrapper: stays alive as the long-lived parent process so macOS
// attributes Screen Recording / Accessibility requests from our children
// (node → peekaboo) to *this* bundle (com.canopy.gvoice).
//
// Earlier this used execv, which replaced our process image with node —
// causing TCC to prompt for "node" instead of CanopyGvoice.app. Spawning
// keeps our identity intact.
//
// Behavior:
//   - Spawn argv[1..] as a child via posix_spawn
//   - Forward SIGTERM/SIGINT/SIGHUP to the child
//   - Exit with the child's exit status (so launchd KeepAlive sees crashes)
import Foundation
import Darwin

// File-scope global so the C-convention signal handler can read it.
var globalChildPid: pid_t = 0

let forwardSignal: @convention(c) (Int32) -> Void = { sig in
    if globalChildPid > 0 {
        _ = kill(globalChildPid, sig)
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: canopy-gvoice <program> [args...]\n".data(using: .utf8)!)
    exit(1)
}

let target = args[1]
let childArgs = Array(args[1...])
let cargs: [UnsafeMutablePointer<CChar>?] = childArgs.map { strdup($0) } + [nil]

var pid: pid_t = 0
let rc = posix_spawn(&pid, target, nil, nil, cargs, environ)
if rc != 0 {
    let msg = "posix_spawn failed: \(String(cString: strerror(rc)))\n"
    FileHandle.standardError.write(msg.data(using: .utf8)!)
    exit(1)
}
globalChildPid = pid

signal(SIGTERM, forwardSignal)
signal(SIGINT, forwardSignal)
signal(SIGHUP, forwardSignal)

var status: Int32 = 0
while true {
    let r = waitpid(pid, &status, 0)
    if r == -1 {
        if errno == EINTR { continue }
        perror("waitpid")
        exit(1)
    }
    break
}

for p in cargs where p != nil { free(p) }

if (status & 0x7f) == 0 {
    exit((status >> 8) & 0xff)
} else {
    exit(128 + (status & 0x7f))
}
