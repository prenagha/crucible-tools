import Foundation

/// Helpful wrapper around config.plist
class Config {

  let props: NSDictionary

  init(path: String) {
    if let dict = NSDictionary(contentsOfFile: path) {
      props = dict
    } else {
      props = NSDictionary()
      LOG.error("Unable to create dictionary from plist \(path)")
    }
  }

  func getURL() -> String {
    if let v = props.object(forKey: "URL") {
      return v as! String
    } else {
      LOG.error("URL key not found in plist")
      return ""
    }
  }

  func getToken() -> String {
    if let v = props.object(forKey: "Token") {
      return v as! String
    } else {
      LOG.error("Token key not found in plist")
      return ""
    }
  }

  func getKillOlderThanDays() -> Int {
    if let v = props.object(forKey: "KillOlderThanDays") {
      let n = v as! NSNumber
      return Int(n.doubleValue)
    } else {
      LOG.error("KillOlderThanDays key not found in plist")
      return 0
    }
  }

}
