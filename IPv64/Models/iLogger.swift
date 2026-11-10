//
//  Logger.swift
//  iGotify
//
//  Created by Sebastian Rank on 23.01.24.
//

import Foundation
@preconcurrency import SwiftyBeaver

public struct iLogger: Sendable {
    
    public static let log = SwiftyBeaver.self
    private var file: FileDestination? = nil
    static let shared = iLogger()
    
    init() {
        
        let console = ConsoleDestination()  // log to Xcode Console
        file = FileDestination()  // log to default swiftybeaver.log file
        file!.logFileURL = defaultLogFileURL()
        console.format = "$DHH:mm:ss$d $L $M"
        // add the destinations to SwiftyBeaver
        iLogger.log.addDestination(console)
        iLogger.log.addDestination(file!)
        rotateLogFileIfNeeded()
        iLogger.log.info("♻️ - Initialize iLogger")
    }
    
    func defaultLogFileURL() -> URL {
        let _ = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ipv64.net")
        let logFileURL = container!.appendingPathComponent("app_\(formatDateToYYYYMMDD(date: Date()))_latest.log")
        return logFileURL
    }
    
    @MainActor
    static func getLogFileURL(log: String) -> URL {
        let _ = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ipv64.net")
        let logFileURL = container!.appendingPathComponent(log)
        return logFileURL
    }
    
    @MainActor
    static func defaultLogPath() -> String {
        let _ = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.ipv64.net")
        return container?.path() ?? ""
    }
    
    // Function to rotate the log file if it exceeds the maximum size
    func rotateLogFileIfNeeded() {
        guard let logFileURL = file!.logFileURL else {
            return
        }
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: logFileURL.path)[.size] as? NSNumber
            let maxSize = NSNumber(value: 1024 * 1024)
            
            if let fileSize = fileSize, fileSize.int64Value > maxSize.int64Value {
                // Rotate the log file by renaming the current file
                let rotatedLogFileURL = logFileURL.deletingLastPathComponent().appendingPathComponent("app_\(formatDateToYYYYMMDD(date: Date())).log")
                try FileManager.default.moveItem(at: logFileURL, to: rotatedLogFileURL)
                
                // Create a new empty log file
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            }
        } catch {
            print("Error rotating log file: \(error)")
        }
    }
    
    func formatDateToYYYYMMDD(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    
    public static func readLogFile(log: String) async -> String {
        let logFileURL = await getLogFileURL(log: log)
        
        do {
            //            let logContent = try String(contentsOf: logFileURL)
            var logContent = ""
            for try await line in logFileURL.lines {
                logContent.append("\n\n\(line.replacingOccurrences(of: "\n", with: "\n  \n", options: .regularExpression))")
            }
            //print("Log File Content:\n\(logContent)")
            return logContent
        } catch {
            //print("Error reading log file: \(error)")
            return "Error reading log file: \(error)"
        }
    }
    
    public static func getFileList() async -> [String] {
        let containerPath = await defaultLogPath()
        if (containerPath.isEmpty) {
            return []
        }
        do {
            let fileList = try FileManager.default.contentsOfDirectory(atPath: containerPath).filter({ $0.contains(".log") })
            return fileList.sorted().reversed()
        } catch _ { }
        return []
    }
    
    public static func removeLogFile(file: String) async -> Bool {
        let logFileUrl = await getLogFileURL(log: file)
        
        do {
            try FileManager.default.removeItem(at: logFileUrl)
            return true
        } catch _ {
            
        }
        return false
    }
}
