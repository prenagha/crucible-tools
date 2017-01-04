import Foundation
import SwiftyBeaver
import Alamofire
import SwiftyJSON

// setup logging
let LOG = SwiftyBeaver.self
let console = ConsoleDestination()
//console.dateFormat = "HH:mm:ss.SSS"
//console.colored = false
LOG.addDestination(console)
let logFile = FileDestination()
logFile.logFileURL = URL(string: "file://" + NSHomeDirectory() + "/Dev/crucible-tools/bin/crucible-tools.log")!
//logFile.colored = false
LOG.addDestination(logFile)
console.minLevel = SwiftyBeaver.Level.debug
logFile.minLevel = SwiftyBeaver.Level.debug

LOG.info("Start")

let plistPath = NSHomeDirectory() + "/Dev/crucible-tools/config.plist"
let CONFIG = Config(path: plistPath)
let CRUCIBLE = Crucible(url: CONFIG.getURL(), token: CONFIG.getToken(),
  killOlderThanDays: CONFIG.getKillOlderThanDays())
let ACCEPT_JSON: HTTPHeaders = ["Accept": "application/json"]
let TOKEN: Parameters = ["FEAUTH": CONFIG.getToken()]

// keep track of response handler running async
let LATCH = CountdownLatch()

// run response handler async in their own queue
let queue = DispatchQueue(label: "my.crucible-queue", attributes: DispatchQueue.Attributes.concurrent)

func draftsResponse(_ response: DataResponse<Any>) {
  switch response.result {
  case .success:
    if let value = response.result.value {
      let json = JSON(value)
      LOG.verbose("Drafts Response JSON: \(json)")
      LOG.info("Read \(json["reviewData"].count) drafts")
      let tooOld = CRUCIBLE.tooOld(json)
      LOG.info("Found \(tooOld.count) too old drafts")
      for id in tooOld {
        doAbandon(id)
      }
    }
  case .failure(let error):
    LOG.error("Error read drafts \(error)")
  }
  LATCH.remove()
}

func doAbandon(_ id: String) {
  LOG.info("Abandoning \(id)")
  let abandonURL = CONFIG.getURL() + id + "/transition"
  var abandonParam = TOKEN
  abandonParam.updateValue("action:abandonReview", forKey: "action")
  LATCH.add()
  Alamofire.request(abandonURL, method: .post, parameters: abandonParam, encoding: URLEncoding.queryString)
    .validate()
    .response(
      queue: queue,
      responseSerializer: DataRequest.stringResponseSerializer(),
      completionHandler: { response in abandonResponse(response, id: id) }
  )
}

func abandonResponse(_ response: DataResponse<String>, id: String) {
  switch response.result {
  case .success:
    LOG.info("Abandoned \(id)")
    doDelete(id)
  case .failure(let error):
    LOG.error("Error abandoning \(id) \(error)")
  }
  LATCH.remove()
}

func doDelete(_ id: String) {
  LOG.info("Deleting \(id)")
  let deleteURL = CONFIG.getURL() + id
  LATCH.add()
  Alamofire.request(deleteURL, method: .delete, parameters: TOKEN, encoding: URLEncoding.queryString)
    .validate()
    .response(
      queue: queue,
      responseSerializer: DataRequest.stringResponseSerializer(),
      completionHandler: { response in deleteResponse(response, id: id) }
  )
}

func deleteResponse(_ response: DataResponse<String>, id: String) {
  switch response.result {
  case .success:
    LOG.info("Deleted \(id)")
  case .failure(let error):
    LOG.error("Error deleting \(id) \(error)")
  }
  LATCH.remove()
}

LOG.info("Getting drafts")
let draftsURL = CONFIG.getURL() + "filter/draftReviews/"
LATCH.add()
Alamofire.request(draftsURL, parameters: TOKEN, headers: ACCEPT_JSON)
  .validate()
  .response(
    queue: queue,
    responseSerializer: DataRequest.jsonResponseSerializer(),
    completionHandler: draftsResponse
)

func openResponse(response: DataResponse<Any>) {
  switch response.result {
  case .success:
    if let value = response.result.value {
      let json = JSON(value)
      LOG.verbose("Open Response JSON: \(json)")
      LOG.info("Read \(json["reviewData"].count) open")
      let tooOld = CRUCIBLE.tooOld(json)
      LOG.info("Found \(tooOld.count) too old open")
      for id in tooOld {
        doClose(id)
      }
    }
  case .failure(let error):
    LOG.error("Error read open \(error)")
  }
  LATCH.remove()
}

func doClose(_ id: String) {
  LOG.info("Closing \(id)")
  let parms = ["summary": "Old review automatically closed"]
  let closeURL = CONFIG.getURL() + id + "/close/?FEAUTH=" + CONFIG.getToken()
  LATCH.add()
  Alamofire.request(closeURL, method: HTTPMethod.post, parameters: parms, encoding: JSONEncoding.default, headers: ACCEPT_JSON)
    .validate()
    .response(
      queue: queue,
      responseSerializer: DataRequest.stringResponseSerializer(),
      completionHandler: { response in closeResponse(response, id: id) }
    )
}

func closeResponse(_ response: DataResponse<String>, id: String) {
  //LOG.verbose("Close Response: \(response.result.value)")
  switch response.result {
  case .success:
    LOG.info("Closed \(id)")
  case .failure(let error):
    LOG.error("Error closing \(id) \(error)")
  }
  LATCH.remove()
}

LOG.info("Getting open")
let openURL = CONFIG.getURL() + "filter/allOpenReviews/"
LATCH.add()
Alamofire.request(openURL, parameters: TOKEN, headers: ACCEPT_JSON)
  .validate()
  .response(
    queue: queue,
    responseSerializer: DataRequest.jsonResponseSerializer(),
    completionHandler: openResponse
)


_ = LATCH.wait(300)
LOG.info("End")
_ = LOG.flush(secondTimeout: 10)
