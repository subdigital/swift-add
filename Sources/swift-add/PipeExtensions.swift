import Foundation

extension Pipe {
    convenience init(handler: @escaping (FileHandle) -> Void) {
        self.init()
        fileHandleForReading.readabilityHandler = handler
    }
}

class PipeToString {
    private(set) var string: String?
    private(set) var pipe: Pipe!
    let queue: DispatchQueue

    init() {
        queue = DispatchQueue(label: "pipe-to-string")
        pipe = Pipe { handler in
            let data = handler.availableData
            if let fragment = String(data: data, encoding: .utf8) {
                self.queue.async {
                    if self.string == nil {
                        self.string = fragment
                    } else {
                        self.string!.append(fragment)
                    }
                }
            }
        }
    }
}

