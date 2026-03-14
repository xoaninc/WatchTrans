//
//  AlertFilteringTests.swift
//  WatchTrans iOSTests
//
//  Tests for alert filtering logic: cross-city collision, partial suspension, per-stop alerts
//

import Foundation
import Testing
@testable import WatchTrans_iOS

// MARK: - Test Helpers

/// Creates a minimal AlertResponse for testing
private func makeAlert(
    alertId: String = "test_alert",
    effect: String? = nil,
    aiStatus: String? = nil,
    aiCategory: String? = nil,
    headerText: String? = "Test alert",
    entities: [InformedEntity] = []
) -> AlertResponse {
    AlertResponse(
        alertId: alertId,
        cause: nil,
        effect: effect,
        headerText: headerText,
        descriptionText: nil,
        url: nil,
        activePeriodStart: nil,
        activePeriodEnd: nil,
        isActive: true,
        informedEntities: entities,
        severity: "warning",
        timestamp: nil,
        updatedAt: nil,
        aiSummary: nil,
        aiSeverity: nil,
        aiCategory: aiCategory,
        aiStatus: aiStatus,
        aiIsVerified: nil,
        estimatedRestorationTime: nil
    )
}

private func makeEntity(
    routeId: String? = nil,
    routeShortName: String? = nil,
    stopId: String? = nil,
    agencyId: String? = nil
) -> InformedEntity {
    InformedEntity(
        routeId: routeId,
        routeShortName: routeShortName,
        stopId: stopId,
        tripId: nil,
        agencyId: agencyId,
        routeType: nil
    )
}

// MARK: - Bug 1: Per-stop alert filtering

/// Tests that alertsForStop correctly filters alerts by stop_id from informed entities
struct PerStopAlertTests {

    @Test func alertMatchesExactStopId() {
        let alert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70103"),
            makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70104")
        ])
        let alerts = [alert]

        let matching = filterAlertsForStop(alerts: alerts, stopId: "RENFE_70103")
        #expect(matching.count == 1)
        #expect(matching.first?.alertId == "test_alert")
    }

    @Test func alertDoesNotMatchDifferentStop() {
        let alert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70103")
        ])

        let matching = filterAlertsForStop(alerts: [alert], stopId: "RENFE_99999")
        #expect(matching.isEmpty)
    }

    @Test func alertMatchesWithRENFEPrefixVariant() {
        // Alert has stopId without prefix, app stop has RENFE_ prefix
        let alert = makeAlert(entities: [
            makeEntity(stopId: "70103")
        ])

        let matching = filterAlertsForStop(alerts: [alert], stopId: "RENFE_70103")
        #expect(matching.count == 1)
    }

    @Test func alertMatchesReverseRENFEPrefixVariant() {
        // Alert has RENFE_ prefix, app stop doesn't
        let alert = makeAlert(entities: [
            makeEntity(stopId: "RENFE_70103")
        ])

        let matching = filterAlertsForStop(alerts: [alert], stopId: "70103")
        #expect(matching.count == 1)
    }

    @Test func routeLevelEntitiesIgnoredForStopFiltering() {
        // Alert with only route-level entities (no stop_id) should NOT match any specific stop
        let alert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_30T0009C5", stopId: nil)
        ])

        let matching = filterAlertsForStop(alerts: [alert], stopId: "RENFE_70103")
        #expect(matching.isEmpty)
    }

    @Test func multipleAlertsFilteredCorrectly() {
        let alertForStop1 = makeAlert(alertId: "a1", entities: [
            makeEntity(stopId: "RENFE_70103")
        ])
        let alertForStop2 = makeAlert(alertId: "a2", entities: [
            makeEntity(stopId: "RENFE_70200")
        ])
        let alertForBoth = makeAlert(alertId: "a3", entities: [
            makeEntity(stopId: "RENFE_70103"),
            makeEntity(stopId: "RENFE_70200")
        ])

        let alerts = [alertForStop1, alertForStop2, alertForBoth]
        let matching = filterAlertsForStop(alerts: alerts, stopId: "RENFE_70103")
        #expect(matching.count == 2)
        let ids = Set(matching.map { $0.alertId })
        #expect(ids.contains("a1"))
        #expect(ids.contains("a3"))
    }
}

// MARK: - Bug 2: Partial suspension (stop-level entities)

/// Tests that full suspension is only true when there are NO stop-level entities
struct PartialSuspensionTests {

    @Test func fullSuspensionWithoutStopEntities() {
        // Route-level only → true full suspension
        let alert = makeAlert(
            aiStatus: "FULL_SUSPENSION",
            entities: [
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: nil)
            ]
        )
        #expect(isLineSuspended(alerts: [alert]) == true)
    }

    @Test func fullSuspensionWithStopEntitiesIsPartial() {
        // Has stop-level entities → partial, NOT full suspension
        let alert = makeAlert(
            aiStatus: "FULL_SUSPENSION",
            entities: [
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: nil),
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70103"),
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70104"),
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70105"),
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: "RENFE_70106")
            ]
        )
        #expect(isLineSuspended(alerts: [alert]) == false)
    }

    @Test func nonSuspensionAlertDoesNotTrigger() {
        let alert = makeAlert(
            aiStatus: "DELAY",
            entities: [makeEntity(routeId: "RENFE_C_30T0009C5")]
        )
        #expect(isLineSuspended(alerts: [alert]) == false)
    }

    @Test func mixedAlerts_onlyRouteLevel_isSuspended() {
        let suspensionAlert = makeAlert(
            alertId: "susp",
            aiStatus: "FULL_SUSPENSION",
            entities: [makeEntity(routeId: "RENFE_C_30T0009C5")]
        )
        let infoAlert = makeAlert(
            alertId: "info",
            aiStatus: "DELAY",
            entities: [makeEntity(routeId: "RENFE_C_30T0009C5")]
        )
        #expect(isLineSuspended(alerts: [suspensionAlert, infoAlert]) == true)
    }

    @Test func aiCategorySuspensionWithStopEntitiesIsPartial() {
        let alert = makeAlert(
            aiCategory: "FULL_SUSPENSION",
            entities: [
                makeEntity(routeId: "RENFE_C_30T0009C5", stopId: nil),
                makeEntity(stopId: "RENFE_70103")
            ]
        )
        #expect(isLineSuspended(alerts: [alert]) == false)
    }
}

// MARK: - Bug 3: Cross-city alert collision (T1 Cádiz vs T1 Sevilla)

/// Tests that alert fallback doesn't match by route_short_name alone when prefix can't disambiguate
struct CrossCityAlertTests {

    @Test func sameRouteIdMatches() {
        let alert = makeAlert(entities: [
            makeEntity(routeId: "TRAM_SEV_ST_T1", routeShortName: "T1")
        ])

        let matching = filterAlertsByRouteId(
            alerts: [alert],
            lineRouteIds: ["TRAM_SEV_ST_T1"],
            lineName: "T1"
        )
        #expect(matching.count == 1)
    }

    @Test func differentRouteIdSameShortNameDoesNotMatch() {
        // Cádiz T1 alert should NOT match Sevilla T1 line
        let cadizAlert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_31T0001T1", routeShortName: "T1")
        ])

        let matching = filterAlertsByRouteId(
            alerts: [cadizAlert],
            lineRouteIds: ["TRAM_SEV_ST_T1"],
            lineName: "T1"
        )
        #expect(matching.isEmpty)
    }

    @Test func sameRENFEPrefixMatches() {
        // C5 Sevilla alert should match C5 Sevilla line (same 30T prefix)
        let alert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_30T0009C5", routeShortName: "C5")
        ])

        // Line routeId also has 30T prefix — prefix match should work
        let matching = filterAlertsByRouteId(
            alerts: [alert],
            lineRouteIds: ["RENFE_C_30T0005C5"],
            lineName: "C5"
        )
        #expect(matching.count == 1)
    }

    @Test func differentRENFEPrefixDoesNotMatch() {
        // C1 Madrid (34T) alert should NOT match C1 Sevilla (30T)
        let madridAlert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C_34T0001C1", routeShortName: "C1")
        ])

        let matching = filterAlertsByRouteId(
            alerts: [madridAlert],
            lineRouteIds: ["RENFE_C1_30T"],
            lineName: "C1"
        )
        #expect(matching.isEmpty)
    }

    @Test func routeIdVariantMatch() {
        // Direct route_id match with RENFE_ variant
        let alert = makeAlert(entities: [
            makeEntity(routeId: "RENFE_C1_30T", routeShortName: "C1")
        ])

        let matching = filterAlertsByRouteId(
            alerts: [alert],
            lineRouteIds: ["RENFE_C1_30T"],
            lineName: "C1"
        )
        #expect(matching.count == 1)
    }

    @Test func noEntitiesDoesNotMatch() {
        let alert = makeAlert(entities: [])

        let matching = filterAlertsByRouteId(
            alerts: [alert],
            lineRouteIds: ["TRAM_SEV_ST_T1"],
            lineName: "T1"
        )
        #expect(matching.isEmpty)
    }
}

// MARK: - Pure functions extracted from view/service for testability

/// Mirrors LineDetailView.alertsForStop logic
private func filterAlertsForStop(alerts: [AlertResponse], stopId: String) -> [AlertResponse] {
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

/// Mirrors LineDetailView.isLineSuspended logic
private func isLineSuspended(alerts: [AlertResponse]) -> Bool {
    alerts.contains { alert in
        guard alert.isFullSuspension else { return false }
        let entities = alert.informedEntities ?? []
        let hasStopEntities = entities.contains { $0.stopId != nil }
        return !hasStopEntities
    }
}

/// Mirrors DataService.fetchAlertsForLine fallback filtering logic
private func filterAlertsByRouteId(
    alerts: [AlertResponse],
    lineRouteIds: [String],
    lineName: String
) -> [AlertResponse] {
    let routeIdVariants = Set(lineRouteIds.flatMap { routeIdVariantsFor($0) })
    let prefixes = routePrefixesFor(lineRouteIds)
    let normalizedShortName = lineName
        .folding(options: .diacriticInsensitive, locale: .current)
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return alerts.filter { alert in
        let entities = alert.informedEntities ?? []
        return entities.contains { entity in
            // First: exact route_id match always wins
            if let entityRouteId = entity.routeId, routeIdVariants.contains(entityRouteId) {
                return true
            }
            // Short name match requires prefix disambiguation
            guard let entityShort = entity.routeShortName,
                  entityShort.folding(options: .diacriticInsensitive, locale: .current)
                      .lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedShortName
            else { return false }

            if let entityRouteId = entity.routeId,
               let entityPrefix = routePrefixFrom(entityRouteId),
               !prefixes.isEmpty {
                return prefixes.contains(entityPrefix)
            }
            // When we can't disambiguate by prefix, don't match
            return false
        }
    }
}

/// Mirrors DataService.alertRouteIdVariants
private func routeIdVariantsFor(_ routeId: String) -> Set<String> {
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

/// Mirrors DataService.alertRoutePrefixes
private func routePrefixesFor(_ routeIds: [String]) -> Set<String> {
    Set(routeIds.compactMap { routePrefixFrom($0) })
}

/// Mirrors DataService.alertRoutePrefix
private func routePrefixFrom(_ routeId: String) -> String? {
    let trimmed = routeId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !trimmed.isEmpty else { return nil }

    if trimmed.contains("_C_") {
        let parts = trimmed.components(separatedBy: "_C_")
        if parts.count > 1 {
            let suffix = parts[1]
            if let tIndex = suffix.firstIndex(of: "T") {
                return String(suffix[...tIndex])
            }
        }
    }

    let normalized = trimmed.replacingOccurrences(of: "RENFE_", with: "")
    if let tIndex = normalized.firstIndex(of: "T") {
        let prefix = String(normalized[...tIndex])
        if let first = prefix.first, first.isNumber {
            return prefix
        }
    }

    return nil
}
