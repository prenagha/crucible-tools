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

  let now = NSDate()
  let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)

  init(url: String, token: String, killOlderThanDays: Int) {
    self.url = url
    self.token = token
    self.killOlderThanDays = killOlderThanDays
  }

  private func tooOld(from: NSDate) -> Bool {
    let components = calendar!.components([.Day], fromDate: from, toDate: now, options: [])
    return components.day >= killOlderThanDays
  }

  func tooOld(json: JSON) -> [String] {
    var old: [String] = []
    for (_, review) in json["reivewData"] {
      let id = review["permaId"]["id"].stringValue
      let createdString = review["createDate"].stringValue
      let created: NSDate
      if tooOld(created) {
        LOG.verbose("\(id) is too old \(created)")
        old.append(id)
      }
    }
    return old
  }
}