import Foundation

/// Lightweight logging in swift, https://github.com/SwiftyBeaver/SwiftyBeaver
import SwiftyBeaver

// setup logging
let LOG = SwiftyBeaver.self
let console = ConsoleDestination()
console.dateFormat = "HH:mm:ss.SSS"
console.colored = false
LOG.addDestination(console)
let logFile = FileDestination()
logFile.logFileURL = NSURL(string: "file://" + NSHomeDirectory() + "/Dev/crucible-tools/bin/crucible-tools.log")!
logFile.colored = false
LOG.addDestination(logFile)

LOG.info("Start")



LOG.info("End")
LOG.flush(10)