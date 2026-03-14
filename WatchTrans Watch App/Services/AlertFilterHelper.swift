//
//  AlertFilterHelper.swift
//  WatchTrans iOS
//
//  Pure functions for alert filtering logic, shared by DataService and views.
//  Extracted for testability — tests call these directly instead of duplicating logic.
//

import Foundation

enum AlertFilterHelper {

    // MARK: - Per-stop filtering

    /// Filter alerts to find those specific to a stop (by stop_id in informed entities).
    /// Route-level alerts (no stop_id) are NOT included — those show in AlertsSummaryView at line level.
    static func alertsForStop(alerts: [AlertResponse], stopId: String) -> [AlertResponse] {
        alerts.filter { alert in
            let entities = alert.informedEntities ?? []
            return entities.contains { entity in
                guard let entityStopId = entity.stopId else { return false }
                return entityStopId == stopId
                    || entityStopId == "RENFE_\(stopId)"
                    || "RENFE_\(entityStopId)" == stopId
            }
        }
    }

    // MARK: - Line suspension

    /// Check if any alert represents a full line suspension (not partial/stop-scoped).
    /// If a FULL_SUSPENSION alert has stop-level entities, it only affects a section.
    static func isLineSuspended(alerts: [AlertResponse]) -> Bool {
        alerts.contains { alert in
            guard alert.isFullSuspension else { return false }
            let entities = alert.informedEntities ?? []
            let hasStopEntities = entities.contains { $0.stopId != nil }
            return !hasStopEntities
        }
    }

    // MARK: - Route ID matching (fallback filtering)

    /// Filter alerts by route_id match + prefix disambiguation.
    /// Used as fallback when server-side filtering returns empty.
    static func filterAlertsByRoute(
        alerts: [AlertResponse],
        lineRouteIds: [String],
        lineName: String
    ) -> [AlertResponse] {
        let routeIdVariants = Set(lineRouteIds.flatMap { alertRouteIdVariants(for: $0) })
        let prefixes = alertRoutePrefixes(for: lineRouteIds)
        let normalizedShortName = normalizeForMatching(lineName)
        guard !normalizedShortName.isEmpty else { return [] }

        return alerts.filter { alert in
            let entities = alert.informedEntities ?? []
            return entities.contains { entity in
                // First: exact route_id match always wins
                if let entityRouteId = entity.routeId, routeIdVariants.contains(entityRouteId) {
                    return true
                }
                // Short name match requires prefix disambiguation to avoid cross-city collisions
                guard let entityShort = entity.routeShortName,
                      normalizeForMatching(entityShort) == normalizedShortName else { return false }
                if let entityRouteId = entity.routeId,
                   let entityPrefix = alertRoutePrefix(from: entityRouteId),
                   !prefixes.isEmpty {
                    return prefixes.contains(entityPrefix)
                }
                // When we can't disambiguate by prefix, don't match
                return false
            }
        }
    }

    // MARK: - ID variant helpers

    static func alertRouteIdVariants(for routeId: String) -> Set<String> {
        let trimmed = routeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var ids: Set<String> = [trimmed]
        if trimmed.hasPrefix("RENFE_") {
            let raw = String(trimmed.dropFirst("RENFE_".count))
            if !raw.isEmpty { ids.insert(raw) }
        } else {
            ids.insert("RENFE_\(trimmed)")
        }
        return ids
    }

    static func alertStopIdVariants(for stopId: String) -> Set<String> {
        let trimmed = stopId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var ids: Set<String> = [trimmed]
        if trimmed.hasPrefix("RENFE_") {
            let raw = String(trimmed.dropFirst("RENFE_".count))
            if !raw.isEmpty { ids.insert(raw) }
        } else {
            ids.insert("RENFE_\(trimmed)")
        }
        return ids
    }

    static func alertRoutePrefixes(for routeIds: [String]) -> Set<String> {
        Set(routeIds.compactMap { alertRoutePrefix(from: $0) })
    }

    static func alertRoutePrefix(from routeId: String) -> String? {
        let trimmed = routeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }

        // Handle "RENFE_C_30T..." -> extract "30T"
        if trimmed.contains("_C_") {
            let parts = trimmed.components(separatedBy: "_C_")
            if parts.count > 1 {
                let suffix = parts[1]
                if let tIndex = suffix.firstIndex(of: "T") {
                    return String(suffix[...tIndex])
                }
            }
        }

        // Handle "RENFE_30T..." -> extract "30T"
        let normalized = trimmed.replacingOccurrences(of: "RENFE_", with: "")
        if let tIndex = normalized.firstIndex(of: "T") {
            let prefix = String(normalized[...tIndex])
            if let first = prefix.first, first.isNumber {
                return prefix
            }
        }

        return nil
    }

    static func normalizeForMatching(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
