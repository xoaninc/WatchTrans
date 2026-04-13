import SwiftUI

#if os(iOS)
import ActivityKit

/// Atributos para la actividad en vivo de un trayecto de tren/metro.
/// Estos datos se comparten entre la App principal y el Widget Extension.
@available(iOS 16.1, *)
struct TrainActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Datos dinámicos que cambian durante el trayecto
        var currentStop: String
        var nextStop: String?
        var minutesRemaining: Int
        var status: String // Ej: "En hora", "Retraso +3 min"
        var progress: Double // 0.0 a 1.0 para la barra de progreso
    }

    // Datos estáticos que no cambian una vez iniciada la actividad
    var lineName: String
    var lineColor: String // Representación Hexadecimal
    var destination: String
}
#endif
