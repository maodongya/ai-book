import AppKit
import Foundation

/// 自进化完成后重新构建并拉起 AIBook。只负责脚本和 relaunch，不改源码。
enum AppRelauncher {
    /// 正式安装位置；存在则 relaunch 这个，而不是 `swift run` 的临时 bundle。
    private static let installedAppPath = "/Applications/AIBook.app"

    /// 构建脚本的结果：成功与否 + 给用户看的输出或错误。
    struct RebuildResult {
        /// 脚本退出码是否为 0。
        let succeeded: Bool
        /// stdout（成功）或合并后的失败细节。
        let message: String?
    }

    /// 下次 open 的目标：已安装 app 优先，否则当前 bundle（开发态）。
    static var relaunchTargetPath: String {
        if FileManager.default.fileExists(atPath: installedAppPath) {
            return installedAppPath // 用户日常用的那份
        }
        return Bundle.main.bundlePath // `swift run` 产物
    }

    /// 跑仓库里的 build-and-install.sh；脚本不存在或失败都返回 succeeded=false。
    static func rebuildIfNeeded(projectPath: String) async -> RebuildResult {
        let scriptPath = (projectPath as NSString).appendingPathComponent("scripts/build-and-install.sh")
        guard FileManager.default.isExecutableFile(atPath: scriptPath) else {
            return RebuildResult(
                succeeded: false,
                message: "未找到可执行的构建脚本：\(scriptPath)" // 开发机没打可执行位时的明确提示
            )
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [scriptPath] // 不经登录壳，避免环境漂移
                process.currentDirectoryURL = URL(fileURLWithPath: projectPath) // 脚本按仓库根找路径
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

    /// 先睡一会儿再 open 目标 app，然后终止当前进程。delay 给脚本落盘留时间。
    static func scheduleRelaunch(delay: TimeInterval = 1.5) {
        let target = relaunchTargetPath.replacingOccurrences(of: "\"", with: "\\\"") // 防路径里的引号打断 -c
        let command = "sleep \(Int(delay)); /usr/bin/open \"\(target)\""

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command] // 独立进程，当前 app 退出后仍会 open
        try? process.run()

        NSApp.terminate(nil) // 走正常退出，触发未保存确认链路
    }

    /// 构建成功才 relaunch；失败清掉自动进化链，避免坏构建循环。
    static func rebuildAndRelaunch(
        projectPath: String,
        relaunchDelay: TimeInterval = 1.5,
        continueChain: Bool = true
    ) async -> RebuildResult {
        let result = await rebuildIfNeeded(projectPath: projectPath)
        guard result.succeeded else {
            AutoEvolutionCoordinator.clearChain() // 失败必须停链，否则会反复打坏包
            return result
        }

        if continueChain {
            AutoEvolutionCoordinator.markChainActive() // 重启后继续下一轮进化
        } else {
            AutoEvolutionCoordinator.clearChain() // 用户只要这一次构建
        }
        await MainActor.run {
            scheduleRelaunch(delay: relaunchDelay) // terminate 必须在主线程
        }
        return result
    }
}
