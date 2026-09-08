import AppKit
import Foundation

/// Rebuilds and relaunches AIBook after self-evolution completes.
enum AppRelauncher {
    private static let installedAppPath = "/Applications/AIBook.app"

    struct RebuildResult {
        let succeeded: Bool
        let message: String?
    }

    static var relaunchTargetPath: String {
        if FileManager.default.fileExists(atPath: installedAppPath) {
            return installedAppPath
        }
        return Bundle.main.bundlePath
    }

    static func rebuildIfNeeded(projectPath: String) async -> RebuildResult {
        let scriptPath = (projectPath as NSString).appendingPathComponent("scripts/build-and-install.sh")
        guard FileManager.default.isExecutableFile(atPath: scriptPath) else {
            return RebuildResult(
                succeeded: false,
                message: "未找到可执行的构建脚本：\(scriptPath)"
            )
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [scriptPath]
                process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr
                do {
                    try process.run()
                    process.waitUntilExit()
                    let outputText = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let errorText = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: RebuildResult(succeeded: true, message: outputText))
                    } else {
                        let details = [errorText, outputText]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }
                            .joined(separator: "\n")
                        let message = details.isEmpty
                            ? "构建脚本退出，状态码：\(process.terminationStatus)"
                            : details
                        continuation.resume(returning: RebuildResult(succeeded: false, message: message))
                    }
                } catch {
                    continuation.resume(returning: RebuildResult(
                        succeeded: false,
                        message: "无法启动构建脚本：\(error.localizedDescription)"
                    ))
                }
            }
        }
    }

    static func scheduleRelaunch(delay: TimeInterval = 1.5) {
        let target = relaunchTargetPath.replacingOccurrences(of: "\"", with: "\\\"")
        let command = "sleep \(Int(delay)); /usr/bin/open \"\(target)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        try? process.run()

        NSApp.terminate(nil)
    }

    static func rebuildAndRelaunch(
        projectPath: String,
        relaunchDelay: TimeInterval = 1.5,
        continueChain: Bool = true
    ) async -> RebuildResult {
        let result = await rebuildIfNeeded(projectPath: projectPath)
        guard result.succeeded else {
            AutoEvolutionCoordinator.clearChain()
            return result
        }

        if continueChain {
            AutoEvolutionCoordinator.markChainActive()
        } else {
            AutoEvolutionCoordinator.clearChain()
        }
        await MainActor.run {
            scheduleRelaunch(delay: relaunchDelay)
        }
        return result
    }
}
