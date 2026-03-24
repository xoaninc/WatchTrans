import SwiftUI

struct TrainAnnotationView: View {
    let train: EstimatedPositionResponse
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                
                SymbolView(name: "TrenSymbol", size: 12)
                    .foregroundStyle(Color.blue) // Podríamos usar el color de la línea si estuviera disponible
            }
            
            Image(systemName: "arrowtriangle.down.fill")
                .resizable()
                .frame(width: 8, height: 6)
                .foregroundStyle(.white)
                .offset(y: -2)
                .shadow(radius: 1)
            
            Text(train.tripId.components(separatedBy: "_").last ?? "Train")
                .font(.caption2)
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
                .offset(y: 2)
        }
    }
}
