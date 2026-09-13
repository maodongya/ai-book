import Foundation

/// 定位本机 `node` 可执行文件，并解析桥接进程的逐行 JSON 事件。不启动进程、不解释业务字段。
enum NodeRuntime {
    /// 一次可调用的 node 入口：绝对路径 + 必须垫在用户参数前的前缀（例如 env 启动时的 `node`）。
    struct Executable: Equatable {
        /// 可执行文件绝对路径，传给 Process.executableURL。
        let path: String
        /// 插在业务参数前面的固定参数；直接命中 node 时为空。
        let prefixArgs: [String]
    }

    /// 按常见安装位置找 node；都没有则退回 `/usr/bin/env node`。找不到可执行文件返回 nil。
    static func resolveExecutable() -> Executable? {
        let candidates = [
            "/opt/homebrew/bin/node", // Apple Silicon Homebrew 默认
            "/usr/local/bin/node", // Intel Homebrew / 手动安装
            "/usr/bin/node", // 系统路径，较少见
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return Executable(path: candidate, prefixArgs: []) // 直接执行该 node，不再套 env
        }

        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/env") else {
            return nil // 连 env 都没有，会话侧应提示未安装 Node
        }
        return Executable(path: "/usr/bin/env", prefixArgs: ["node"]) // 让 env 在 PATH 里找 node，适合 nvm 用户
    }

    /// 把 stdout/stderr 字节按行拆成 JSON 对象；非 JSON 或空行丢掉，避免桥接日志把解码打爆。
    static func jsonEventLines(from data: Data) -> [[String: Any]] {
        guard let text = String(data: data, encoding: .utf8) else { return [] } // 非 UTF-8 当空，不猜测编码
        return text
            .components(separatedBy: .newlines) // 桥接约定一行一个 JSON 事件
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines) // 去掉 \r 和空格，防止尾空白导致解码失败
                guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return nil } // 空行不是事件
                return try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] // 解析失败当日志行丢弃
            }
    }

    /// 只要最后一条成功解析的事件，给「当前状态以最后一帧为准」的调用方。
    static func lastJSONEvent(from data: Data) -> [String: Any]? {
        jsonEventLines(from: data).last // 复用逐行解析，不另写一套拆行
    }
}
