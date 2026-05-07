import Foundation
import AppKit

public enum LogLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
}

public class AppLogger {
    public static let shared = AppLogger()
    private let fileManager = FileManager.default
    private var logFileURL: URL?
    public var logFilePath: String? { logFileURL?.path }
    public var isConsoleMuted = false

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        guard let logsDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/com.subtitleedit.native") else {
            return
        }

        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFileURL = logsDir.appendingPathComponent("app.log")
        
        log("--- Application Started ---", level: .info)
    }

    public func log(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(message)\n"

        // Print to console
        if !isConsoleMuted {
            print(logEntry, terminator: "")
        }

        // Write to file
        if let url = logFileURL {
            if let data = logEntry.data(using: .utf8) {
                if fileManager.fileExists(atPath: url.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: url) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }

    public func showLogsInFinder() {
        if let url = logFileURL {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
}

// Global helper for easy logging
public func AppLog(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line) {
    AppLogger.shared.log(message, level: level, file: file, line: line)
}
