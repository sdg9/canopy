// Minimal launcher: execvs argv[1..] so the running process inherits this
// .app bundle's TCC grants (Screen Recording, Accessibility). Compiled into
// CanopyGvoice.app/Contents/MacOS/canopy-gvoice by build.sh.
import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: canopy-gvoice <program> [args...]\n".data(using: .utf8)!)
    exit(1)
}

let target = args[1]
let cargs = args[1...].map { strdup($0) } + [UnsafeMutablePointer<CChar>?(nil)]
execv(target, cargs)
perror("execv")
exit(1)
