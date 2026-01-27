//
//  FrequentStopsService.swift
//  WatchTrans iOS
//
//  Created by Claude on 27/1/26.
//  Auto-detects frequently visited stops based on usage patterns
//

import Foundation
import Combine

/// Service for tracking and detecting frequently visited stops
class FrequentStopsService: ObservableObject {
    static let shared = FrequentStopsService()

    // MARK: - Published State

    @Published private(set) var frequentStops: [FrequentStop] = []

    // MARK: - Configuration

    private let maxHistoryDays = 30
    private let minVisitsForFrequent = 3
    private let maxFrequentStops = 5

    // MARK: - Storage

    private let userDefaults = UserDefaults.standard
    private let historyKey = "stopVisitHistory"
    private let frequentStopsKey = "frequentStops"

    // MARK: - Models

    struct StopVisit: Codable {
        let stopId: String
        let stopName: String
        let timestamp: Date
        let dayOfWeek: Int // 1=Sunday, 2=Monday, etc.
        let hourOfDay: Int // 0-23
    }

    struct FrequentStop: Codable, Identifiable {
        let id: String // stopId
        let name: String
        let visitCount: Int
        let lastVisit: Date
        let primaryDayOfWeek: Int? // Most common day
        let primaryHourOfDay: Int? // Most common hour
        let isWeekdayPattern: Bool // True if mostly Mon-Fri
    }

    // MARK: - Init

    private init() {
        loadFrequentStops()
    }

    // MARK: - Public Methods

    /// Record a stop visit (call when user views a stop)
    func recordVisit(stopId: String, stopName: String) {
        var history = loadHistory()

        let calendar = Calendar.current
        let now = Date()

        let visit = StopVisit(
            stopId: stopId,
            stopName: stopName,
            timestamp: now,
            dayOfWeek: calendar.component(.weekday, from: now),
            hourOfDay: calendar.component(.hour, from: now)
        )

        history.append(visit)

        // Prune old history
        let cutoffDate = calendar.date(byAdding: .day, value: -maxHistoryDays, to: now) ?? now
        history = history.filter { $0.timestamp > cutoffDate }

        saveHistory(history)
        analyzePatterns(from: history)
    }

    /// Get suggested stops based on current time
    func getSuggestedStops() -> [FrequentStop] {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentDayOfWeek = calendar.component(.weekday, from: now)
        let isWeekday = (2...6).contains(currentDayOfWeek) // Mon-Fri

        // Sort by relevance to current time
        return frequentStops.sorted { stop1, stop2 in
            let score1 = relevanceScore(for: stop1, hour: currentHour, dayOfWeek: currentDayOfWeek, isWeekday: isWeekday)
            let score2 = relevanceScore(for: stop2, hour: currentHour, dayOfWeek: currentDayOfWeek, isWeekday: isWeekday)
            return score1 > score2
        }
    }

    /// Clear all history and frequent stops
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
        userDefaults.removeObject(forKey: frequentStopsKey)
        frequentStops = []
    }

    // MARK: - Private Methods

    private func loadHistory() -> [StopVisit] {
        guard let data = userDefaults.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([StopVisit].self, from: data)) ?? []
    }

    private func saveHistory(_ history: [StopVisit]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        userDefaults.set(data, forKey: historyKey)
    }

    private func loadFrequentStops() {
        guard let data = userDefaults.data(forKey: frequentStopsKey) else { return }
        frequentStops = (try? JSONDecoder().decode([FrequentStop].self, from: data)) ?? []
    }

    private func saveFrequentStops() {
        guard let data = try? JSONEncoder().encode(frequentStops) else { return }
        userDefaults.set(data, forKey: frequentStopsKey)
    }

    private func analyzePatterns(from history: [StopVisit]) {
        // Group visits by stop
        let groupedByStop = Dictionary(grouping: history) { $0.stopId }

        var newFrequentStops: [FrequentStop] = []

        for (stopId, visits) in groupedByStop {
            guard visits.count >= minVisitsForFrequent else { continue }

            let stopName = visits.first?.stopName ?? stopId

            // Find most common day of week
            let dayGroups = Dictionary(grouping: visits) { $0.dayOfWeek }
            let primaryDay = dayGroups.max(by: { $0.value.count < $1.value.count })?.key

            // Find most common hour
            let hourGroups = Dictionary(grouping: visits) { $0.hourOfDay }
            let primaryHour = hourGroups.max(by: { $0.value.count < $1.value.count })?.key

            // Check if weekday pattern (Mon-Fri)
            let weekdayVisits = visits.filter { (2...6).contains($0.dayOfWeek) }
            let isWeekdayPattern = Double(weekdayVisits.count) / Double(visits.count) > 0.7

            let lastVisit = visits.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? Date()

            newFrequentStops.append(FrequentStop(
                id: stopId,
                name: stopName,
                visitCount: visits.count,
                lastVisit: lastVisit,
                primaryDayOfWeek: primaryDay,
                primaryHourOfDay: primaryHour,
                isWeekdayPattern: isWeekdayPattern
            ))
        }

        // Sort by visit count and take top N
        let sortedStops = newFrequentStops
            .sorted { $0.visitCount > $1.visitCount }
            .prefix(maxFrequentStops)
            .map { $0 }

        // Update on main thread since frequentStops is @Published
        DispatchQueue.main.async {
            self.frequentStops = sortedStops
            self.saveFrequentStops()
        }
    }

    private func relevanceScore(for stop: FrequentStop, hour: Int, dayOfWeek: Int, isWeekday: Bool) -> Double {
        var score = Double(stop.visitCount)

        // Boost if matches primary hour (within 2 hours)
        if let primaryHour = stop.primaryHourOfDay {
            let hourDiff = abs(primaryHour - hour)
            if hourDiff <= 2 {
                score += 10.0 - Double(hourDiff) * 3.0
            }
        }

        // Boost if matches primary day
        if let primaryDay = stop.primaryDayOfWeek, primaryDay == dayOfWeek {
            score += 5.0
        }

        // Boost if weekday pattern matches current
        if stop.isWeekdayPattern && isWeekday {
            score += 3.0
        }

        // Recency bonus (visited in last 7 days)
        let daysSinceVisit = Calendar.current.dateComponents([.day], from: stop.lastVisit, to: Date()).day ?? 0
        if daysSinceVisit <= 7 {
            score += 2.0
        }

        return score
    }
}

// MARK: - Convenience Extensions

extension FrequentStopsService.FrequentStop {
    /// Human-readable pattern description
    var patternDescription: String? {
        var parts: [String] = []

        if let hour = primaryHourOfDay {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            parts.append("~\(formatter.string(from: date))")
        }

        if isWeekdayPattern {
            parts.append("L-V")
        } else if let day = primaryDayOfWeek {
            let weekdaySymbols = Calendar.current.shortWeekdaySymbols
            if day >= 1 && day <= 7 {
                parts.append(weekdaySymbols[day - 1])
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
