import Foundation

enum SpeechBridgeService {
    private final class RunHandle: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?

        func setProcess(_ process: Process) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func terminate() {
            lock.lock()
            process?.terminate()
            process = nil
            lock.unlock()
        }
    }

    enum BridgeError: LocalizedError {
        case bridgeNotFound
        case nodeNotFound
        case scriptMissing
        case invalidResponse
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .bridgeNotFound:
                return "未找到 speech-bridge。请在 ai-book/speech-bridge 目录运行 npm install。"
            case .nodeNotFound:
                return "未找到 Node.js 18+，无法合成在线女声。"
            case .scriptMissing:
                return "未找到 speech-bridge/synthesize.mjs。"
            case .invalidResponse:
                return "语音桥接返回了无法解析的内容。"
            case .processFailed(let message):
                return message
            }
        }
    }

    static func synthesize(
        text: String,
        voiceID: String,
        outputFormat: String = "AUDIO_24KHZ_48KBITRATE_MONO_MP3",
        prosody: (rate: String, pitch: String, volume: String)? = nil
    ) async throws -> Data {
        guard let bridge = defaultBridgeDirectory() else {
            throw BridgeError.bridgeNotFound
        }

        let scriptURL = bridge.appendingPathComponent("synthesize.mjs")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw BridgeError.scriptMissing
        }

        let nodeModules = bridge.appendingPathComponent("node_modules", isDirectory: true)
        guard FileManager.default.fileExists(atPath: nodeModules.path) else {
            throw BridgeError.bridgeNotFound
        }

        guard let node = NodeRuntime.resolveExecutable() else {
            throw BridgeError.nodeNotFound
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aibook-tts-\(UUID().uuidString).mp3")

        let payload: [String: Any] = [
            "text": text,
            "voice": voiceID,
            "outputFormat": outputFormat,
            "rate": prosody?.rate ?? "+0%",
            "pitch": prosody?.pitch ?? "+0Hz",
            "volume": prosody?.volume ?? "+0%",
            "outputPath": outputURL.path,
        ]
        let inputData = try JSONSerialization.data(withJSONObject: payload)

        let runHandle = RunHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                var capturedOutput = Data()
                var capturedError = Data()
                var didResume = false

                func finish(_ result: Result<Data, Error>) {
                    guard !didResume else { return }
                    didResume = true
                    runHandle.terminate()
                    try? FileManager.default.removeItem(at: outputURL)
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: node.path)
                    process.arguments = node.prefixArgs + [scriptURL.path]
                    process.currentDirectoryURL = bridge
                    runHandle.setProcess(process)

                    let stdin = Pipe()
                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardInput = stdin
                    process.standardOutput = stdout
                    process.standardError = stderr

                    let outputHandle = stdout.fileHandleForReading
                    let errorHandle = stderr.fileHandleForReading

                    outputHandle.readabilityHandler = { handle in
                        let chunk = handle.availableData
                        if !chunk.isEmpty {
                            capturedOutput.append(chunk)
                        }
                    }

                    errorHandle.readabilityHandler = { handle in
                        let chunk = handle.availableData
                        if !chunk.isEmpty {
                            capturedError.append(chunk)
                        }
                    }

                    process.terminationHandler = { proc in
                        outputHandle.readabilityHandler = nil
                        errorHandle.readabilityHandler = nil

                        capturedOutput.append(outputHandle.readDataToEndOfFile())
                        capturedError.append(errorHandle.readDataToEndOfFile())

                        guard proc.terminationStatus == 0 else {
                            let stderrText = String(data: capturedError, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let message = stderrText?.isEmpty == false
                                ? stderrText!
                                : "语音合成进程退出（\(proc.terminationStatus)）"
                            finish(.failure(BridgeError.processFailed(message)))
                            return
                        }

                        guard let json = NodeRuntime.lastJSONEvent(from: capturedOutput),
                              let event = json["event"] as? String else {
                            finish(.failure(BridgeError.invalidResponse))
                            return
                        }

                        if event == "error" {
                            let message = json["error"] as? String ?? "语音合成失败"
                            finish(.failure(BridgeError.processFailed(message)))
                            return
                        }

                        guard event == "done" else {
                            finish(.failure(BridgeError.invalidResponse))
                            return
                        }

                        if let outputPath = json["outputPath"] as? String {
                            let fileURL = URL(fileURLWithPath: outputPath)
                            do {
                                let audio = try Data(contentsOf: fileURL)
                                guard !audio.isEmpty else {
                                    finish(.failure(BridgeError.invalidResponse))
                                    return
                                }
                                try? FileManager.default.removeItem(at: fileURL)
                                finish(.success(audio))
                            } catch {
                                finish(.failure(error))
                            }
                            return
                        }

                        if
                            let base64 = json["audioBase64"] as? String,
                            let audio = Data(base64Encoded: base64),
                            !audio.isEmpty
                        {
                            finish(.success(audio))
                            return
                        }

                        finish(.failure(BridgeError.invalidResponse))
                    }

                    try process.run()
                    stdin.fileHandleForWriting.write(inputData)
                    stdin.fileHandleForWriting.closeFile()
                } catch {
                    finish(.failure(error))
                }
                }
            }
        } onCancel: {
            runHandle.terminate()
        }
    }

    static func defaultBridgeDirectory() -> URL? {
        if let bundled = bundledBridgeDirectory() {
            return bundled
        }

        if let project = CursorService.defaultProjectDirectory() {
            let bridge = project.appendingPathComponent("speech-bridge", isDirectory: true)
            if FileManager.default.fileExists(atPath: bridge.appendingPathComponent("package.json").path) {
                return bridge
            }
        }

        return nil
    }

    static func bundledBridgeDirectory() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let bridge = resources.appendingPathComponent("speech-bridge", isDirectory: true)
        if FileManager.default.fileExists(atPath: bridge.appendingPathComponent("package.json").path) {
            return bridge
        }
        return nil
    }

}
