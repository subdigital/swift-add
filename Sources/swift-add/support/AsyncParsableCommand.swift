import ArgumentParser

protocol AsyncParsableCommand: ParsableCommand {
    mutating func runAsync() async throws
}

extension ParsableCommand {
    static func main() async {
        do {
            var command = try parseAsRoot(nil)
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.runAsync()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }
}
