//
//  Crucible.swift
//  crucible-tools
//
//  Created by Padraic Renaghan on 2/29/16.
//  Copyright © 2016 Renaghan. All rights reserved.
//

import Foundation
import SwiftyJSON

struct Crucible {

  let url: String
  let token: String
  let killOlderThanDays: Int

  let now = Date()
  let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
  let formatter = DateFormatter()

  init(url: String, token: String, killOlderThanDays: Int) {
    self.url = url
    self.token = token
    self.killOlderThanDays = killOlderThanDays
    self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
  }

  fileprivate func tooOld(_ from: Date) -> Bool {
    let components = (calendar as NSCalendar).components([.day], from: from, to: now, options: [])
    return components.day! >= killOlderThanDays
  }

  func tooOld(_ json: JSON) -> [String] {
    var old: [String] = []
    for (_, review) in json["reviewData"] {
      let id = review["permaId"]["id"].stringValue
      let state = review["state"].stringValue
      if state == "Closed" {
        continue
      }
      let createdString = review["createDate"].stringValue
      let created = formatter.date(from: createdString)!
      if tooOld(created) {
        LOG.verbose("\(id) is too old \(createdString)")
        old.append(id)
      }
    }
    return old
  }
}
