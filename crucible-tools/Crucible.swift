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
  let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
  let formatter = NSDateFormatter()

  init(url: String, token: String, killOlderThanDays: Int) {
    self.url = url
    self.token = token
    self.killOlderThanDays = killOlderThanDays
    self.formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
  }

  private func tooOld(from: NSDate) -> Bool {
    let components = calendar.components([.Day], fromDate: from, toDate: now, options: [])
    return components.day >= killOlderThanDays
  }

  func tooOld(json: JSON) -> [String] {
    var old: [String] = []
    for (_, review) in json["reviewData"] {
      let id = review["permaId"]["id"].stringValue
      let createdString = review["createDate"].stringValue
      let created = formatter.dateFromString(createdString)!
      if tooOld(created) {
        LOG.verbose("\(id) is too old \(createdString)")
        old.append(id)
      }
    }
    return old
  }
}