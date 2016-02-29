import Foundation
import SwiftyBeaver
import Alamofire
import SwiftyJSON

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

let plistPath = NSHomeDirectory() + "/Dev/crucible-tools/config.plist"
let CONFIG = Config(path: plistPath)
let CRUCIBLE = Crucible(url: CONFIG.getURL(), token: CONFIG.getToken(),
  killOlderThanDays: CONFIG.getKillOlderThanDays())

// keep track of response handler running async
let latch = CountdownLatch()

// run response handler async in their own queue
let queue = dispatch_queue_create("my.crucible-queue", DISPATCH_QUEUE_CONCURRENT)

let draftsURL = CONFIG.getURL() + "filter/draftReviews/"
let headers = ["Accept": "application/json"]
latch.add()
Alamofire.request(.GET, draftsURL, parameters: ["FEAUTH": CONFIG.getToken()], headers: headers)
  .validate()
  .response(
    queue: queue,
    responseSerializer: Request.JSONResponseSerializer(options: .AllowFragments),
    completionHandler: { response in
      switch response.result {
      case .Success:
        if let value = response.result.value {
          let json = JSON(value)
          LOG.info("Read \(json["reviewData"].count) drafts")
          let tooOld = CRUCIBLE.tooOld(json)
          LOG.info("Found \(tooOld.count) drafts older than \(CONFIG.getKillOlderThanDays()) days")
          //LOG.verbose("JSON: \(json)")
        }
      case .Failure(let error):
        LOG.error(error)
      }
      latch.remove()
    }
)

latch.wait(60)
LOG.info("End")
LOG.flush(10)