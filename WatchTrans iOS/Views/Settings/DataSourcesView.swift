import SwiftUI

struct DataSourcesView: View {
    var body: some View {
        List {
            Section {
                Text("WatchTrans utiliza datos de transporte público proporcionados por los siguientes operadores oficiales:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section("Operadores") {
                VStack(alignment: .leading, spacing: 12) {
                    AttributionRow(name: "Renfe", description: "Origen de los datos: Renfe Operadora", url: "data.renfe.com")
                    
                    AttributionRow(name: "NAP (National Access Point)", description: "Ministerio de Transportes y Movilidad Sostenible - España", url: "nap.transportes.gob.es")
                    
                    AttributionRow(name: "TMB", description: "Transports Metropolitans de Barcelona", url: "developer.tmb.cat")
                    
                    AttributionRow(name: "FGC", description: "Ferrocarrils de la Generalitat de Catalunya - CC BY 4.0", url: "dadesobertes.fgc.cat")
                    
                    AttributionRow(name: "CRTM", description: "Consorcio Regional de Transportes de Madrid", url: "datos.crtm.es")
                    
                    AttributionRow(name: "Euskotren", description: "Euskotren - Gobierno Vasco - CC BY 4.0", url: "opendata.euskadi.eus")
                    
                    AttributionRow(name: "Metro Bilbao", description: "Metro Bilbao - RISP Ley 37/2007 + CC", url: "metrobilbao.eus")
                }
                .padding(.vertical, 4)
            }
            
            Section("Aviso Legal") {
                Text("Los datos de transporte son provistos 'como están' por los operadores oficiales. WatchTrans no garantiza la exactitud, actualidad o disponibilidad de la información. El uso de estos datos está sujeto a las políticas de datos abiertos de cada organismo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Fuentes de datos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AttributionRow: View {
    let name: String
    let description: String
    let url: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(url)
                .font(.caption)
                .foregroundStyle(.blue)
        }
    }
}

#Preview {
    NavigationStack {
        DataSourcesView()
    }
}
