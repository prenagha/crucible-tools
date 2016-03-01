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
let ACCEPT_JSON = ["Accept": "application/json"]
let TOKEN = ["FEAUTH": CONFIG.getToken()]

// keep track of response handler running async
let LATCH = CountdownLatch()

// run response handler async in their own queue
let queue = dispatch_queue_create("my.crucible-queue", DISPATCH_QUEUE_CONCURRENT)

func draftsResponse(response: Response<AnyObject, NSError>) {
  switch response.result {
  case .Success:
    if let value = response.result.value {
      let json = JSON(value)
      //LOG.verbose("Drafts Response JSON: \(json)")
      LOG.info("Read \(json["reviewData"].count) drafts")
      let tooOld = CRUCIBLE.tooOld(json)
      LOG.info("Found \(tooOld.count) too old drafts")
      for id in tooOld {
        doAbandon(id)
      }
    }
  case .Failure(let error):
    LOG.error("Error read drafts \(error)")
  }
  LATCH.remove()
}

func doAbandon(id: String) {
  LOG.info("Abandoning \(id)")
  let abandonURL = CONFIG.getURL() + id + "/transition"
  var abandonParam = TOKEN
  abandonParam.updateValue("action:abandonReview", forKey: "action")
  LATCH.add()
  Alamofire.request(.POST, abandonURL, parameters: abandonParam, encoding: ParameterEncoding.URLEncodedInURL)
    .validate()
    .response(
      queue: queue,
      responseSerializer: Request.stringResponseSerializer(),
      completionHandler: { response in abandonResponse(response, id: id) }
  )
}

func abandonResponse(response: Response<String, NSError>, id: String) {
  switch response.result {
  case .Success:
    LOG.info("Abandoned \(id)")
    doDelete(id)
  case .Failure(let error):
    LOG.error("Error abandoning \(id) \(error)")
  }
  LATCH.remove()
}

func doDelete(id: String) {
  LOG.info("Deleting \(id)")
  let deleteURL = CONFIG.getURL() + id
  LATCH.add()
  Alamofire.request(.DELETE, deleteURL, parameters: TOKEN)
    .validate()
    .response(
      queue: queue,
      responseSerializer: Request.stringResponseSerializer(),
      completionHandler: { response in deleteResponse(response, id: id) }
  )
}

func deleteResponse(response: Response<String, NSError>, id: String) {
  switch response.result {
  case .Success:
    LOG.info("Deleted \(id)")
  case .Failure(let error):
    LOG.error("Error deleting \(id) \(error)")
  }
  LATCH.remove()
}

LOG.info("Getting drafts")
let draftsURL = CONFIG.getURL() + "filter/draftReviews/"
LATCH.add()
Alamofire.request(.GET, draftsURL, parameters: TOKEN, headers: ACCEPT_JSON)
  .validate()
  .response(
    queue: queue,
    responseSerializer: Request.JSONResponseSerializer(),
    completionHandler: draftsResponse
)

func openResponse(response: Response<AnyObject, NSError>) {
  switch response.result {
  case .Success:
    if let value = response.result.value {
      let json = JSON(value)
      //LOG.verbose("Open Response JSON: \(json)")
      LOG.info("Read \(json["reviewData"].count) open")
      let tooOld = CRUCIBLE.tooOld(json)
      LOG.info("Found \(tooOld.count) too old open")
      for id in tooOld {
        //doClose(id)
      }
    }
  case .Failure(let error):
    LOG.error("Error read open \(error)")
  }
  LATCH.remove()
}

func doClose(id: String) {
  LOG.info("Closing \(id)")
  let closeURL = CONFIG.getURL() + id + "/close/"
  LATCH.add()
  Alamofire.request(.POST, closeURL, parameters: TOKEN)
    .validate()
    .response(
      queue: queue,
      responseSerializer: Request.stringResponseSerializer(),
      completionHandler: { response in closeResponse(response, id: id) }
  )
}

func closeResponse(response: Response<String, NSError>, id: String) {
  switch response.result {
  case .Success:
    LOG.info("Closed \(id)")
  case .Failure(let error):
    LOG.error("Error closing \(id) \(error)")
  }
  LATCH.remove()
}

LOG.info("Getting open")
let openURL = CONFIG.getURL() + "filter/allOpenReviews/"
LATCH.add()
Alamofire.request(.GET, openURL, parameters: TOKEN, headers: ACCEPT_JSON)
  .validate()
  .response(
    queue: queue,
    responseSerializer: Request.JSONResponseSerializer(),
    completionHandler: openResponse
)


LATCH.wait(300)
LOG.info("End")
LOG.flush(10)