import WidgetKit
import SwiftUI
import ActivityKit

struct TrainLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainActivityAttributes.self) { context in
            // VISTA PANTALLA DE BLOQUEO / BANNER
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Usamos el color opcional con un fallback
                    Text(context.attributes.lineName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: context.attributes.lineColor) ?? .blue)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                    
                    Text("→ \(context.attributes.destination)")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(context.state.minutesRemaining) min")
                        .font(.title3.bold())
                        .foregroundStyle(context.state.minutesRemaining < 5 ? .orange : .primary)
                }
                
                // Barra de progreso
                ProgressView(value: context.state.progress)
                    .tint(Color(hex: context.attributes.lineColor) ?? .blue)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                
                HStack {
                    Label(context.state.currentStop, systemImage: "tram.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(context.state.status)
                        .font(.caption.bold())
                        .foregroundStyle(context.state.status.contains("+") ? .orange : .green)
                }
            }
            .padding()
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Isla Expandida
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.lineName)
                        .font(.title2.bold())
                        .foregroundStyle(Color(hex: context.attributes.lineColor) ?? .blue)
                        .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(context.state.minutesRemaining)")
                            .font(.title.bold())
                        Text("min")
                            .font(.caption2.bold())
                    }
                    .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Próxima: \(context.state.nextStop ?? context.attributes.destination)")
                            .font(.subheadline.bold())
                        
                        ProgressView(value: context.state.progress)
                            .tint(Color(hex: context.attributes.lineColor) ?? .blue)
                    }
                    .padding(.horizontal)
                }
                
            } compactLeading: {
                Text(context.attributes.lineName)
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: context.attributes.lineColor) ?? .blue)
            } compactTrailing: {
                Text("\(context.state.minutesRemaining)m")
                    .font(.caption.bold())
            } minimal: {
                Text("\(context.state.minutesRemaining)")
                    .font(.caption.bold())
            }
            .keylineTint(Color(hex: context.attributes.lineColor) ?? .blue)
        }
    }
}
// HE ELIMINADO LA EXTENSIÓN DUPLICADA DE COLOR PARA USAR LA QUE YA EXISTE EN EL PROYECTO