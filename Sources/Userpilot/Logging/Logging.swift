//
//  Logging.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
// [Brief Description]
// Logging extra layer over OSLog to custom the logging logic
//

import Foundation
import os.log

internal enum UserpilotLogging {
    static let subsystem = "com.userpilot.sdk"
    static let general = "general"
}

/**
 Logging protocol to log SDK logs
 */
internal protocol Logging {
    func debug(_ message: StaticString, _ args: CVarArg...)
    func info(_ message: StaticString, _ args: CVarArg...)
    func log(_ message: StaticString, _ args: CVarArg...)
    func error(_ message: StaticString, _ args: CVarArg...)
    func fault(_ message: StaticString, _ args: CVarArg...)
}

/*
 Convenience methods to make the logging call site a bit tidier:
 `logger.error("%{private}@", data)`
 vs
 `os_log("%{private}@", log: .default, type: .error, data)`
 
 This also saves us having to `import os.log` everywhere.
 */
extension OSLog: Logging {

    /// Create an userpilot logger.
    convenience init(userpilotCategory category: String) {
        self.init(subsystem: UserpilotLogging.subsystem, category: category)
    }

    /*
     Use this level to capture information that may be useful during
     development or while troubleshooting a specific problem.
     */
    func debug(
        _ message: StaticString,
        _ args: CVarArg...
    ) {
        log(message, type: .debug, args)
    }

    /// Use this level to capture information that may be helpful, but not essential, for troubleshooting errors.
    func info(
        _ message: StaticString,
        _ args: CVarArg...
    ) {
        log(message, type: .info, args)
    }

    /// Use this level to capture information about things that might result in a failure.
    func log(
        _ message: StaticString,
        _ args: CVarArg...
    ) {
        log(message, type: .default, args)
    }

    /// Use this log level to report process-level errors.
    func error(
        _ message: StaticString,
        _ args: CVarArg...
    ) {
        log(message, type: .error, args)
    }

    /// Use this level only to capture system-level or multiprocess information when reporting system errors.
    func fault(
        _ message: StaticString,
        _ args: CVarArg...
    ) {
        log(message, type: .fault, args)
    }

    private func log(
        _ message: StaticString,
        type: OSLogType,
        _ args: [CVarArg]
    ) {
        tryCatch {
            /*
             Swift doesn't support splatting so unfortunately `args` needs to be manually enumerated.
             Limiting it to 5 since that seems reasonable.
             */
            guard args.count <= 5 else {
                error("Too many log args. 5 are supported, %{public}d passed.", args.count)
                return
            }

            switch args.count {
            case 1:
                os_log(message, log: self, type: type, args[0])
            case 2:
                os_log(message, log: self, type: type, args[0], args[1])
            case 3:
                os_log(message, log: self, type: type, args[0], args[1], args[2])
            case 4:
                os_log(message, log: self, type: type, args[0], args[1], args[2], args[3])
            case 5:
                os_log(message, log: self, type: type, args[0], args[1], args[2], args[3], args[4])
            default:
                os_log(message, log: self, type: type)
            }
        }
    }
}
