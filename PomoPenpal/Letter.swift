//
//  Letter.swift
//  PomoPenpal
//

import Foundation
import SwiftData

/// One completed work session.
///
/// `weekIndex` uses **ISO 8601** week-of-year (`Calendar(identifier: .iso8601)`):
/// weeks run Monday → Sunday and week 1 contains the first Thursday of the year.
/// Picked over a naive "Monday-anchored from Jan 1" scheme because ISO is
/// well-defined across year boundaries and matches Apple's calendar component
/// `.yearForWeekOfYear` out of the box. The packed `yearForWeekOfYear * 100 +
/// weekOfYear` form (e.g. 202621 for week 21 of 2026) keeps weeks sortable and
/// filterable in one int — Dec 28-31 that ISO assigns to next year's week 1
/// still groups with the right week.
@Model
final class Letter {
    var id: UUID
    var dateEarned: Date
    var weekIndex: Int

    init(id: UUID = UUID(), dateEarned: Date = .now) {
        self.id = id
        self.dateEarned = dateEarned
        self.weekIndex = Letter.weekIndex(for: dateEarned)
    }

    static func weekIndex(for date: Date) -> Int {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let year = cal.component(.yearForWeekOfYear, from: date)
        let week = cal.component(.weekOfYear, from: date)
        return year * 100 + week
    }

    static func currentWeekIndex(now: Date = .now) -> Int {
        weekIndex(for: now)
    }
}
