import SwiftUI
import MapKit

struct SettingsOfficeView: View {
    private enum Field: Hashable {
        case label, address
    }
    
    @State private var viewModel = OfficeViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.4),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )
    @FocusState private var focusedField: Field?
    
    var body: some View {
        Form {
            Section("Bureau") {
                TextField("Nom du bureau", text: $viewModel.label)
                    .focused($focusedField, equals: .label)
            }
            
            Section("Adresse") {
                TextField("Rechercher une adresse", text: $viewModel.addressQuery)
                    .focused($focusedField, equals: .address)
                Button("Localiser") {
                    Task { await viewModel.geocodeAddress() }
                }
                if let geocodingError = viewModel.geocodingError {
                    Text(geocodingError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            
            Section {
                // iOS 26: .onTapGesture on a Map is a confirmed Apple bug —
                // it silently never fires. .simultaneousGesture(SpatialTapGesture())
                // is the documented workaround. Do not revert to the
                // "standard" onTapGesture pattern shown in tutorials.
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if let coordinate = viewModel.coordinate {
                            Marker(viewModel.label.isEmpty ? "Bureau" : viewModel.label, coordinate: coordinate)
                        }
                    }
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { value in
                            if let coordinate = proxy.convert(value.location, from: .local) {
                                viewModel.coordinate = coordinate
                            }
                        }
                    )
                }
            }
            .frame(height: 250)
            .listRowInsets(EdgeInsets())
            
            Section {
                Button("Enregistrer") {
                    Task { await viewModel.save() }
                }
                .disabled(viewModel.saveState == .saving)
                
                if case .failed(let message) = viewModel.saveState {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Bureau")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") {
                    focusedField = nil
                }
            }
        }
        .task {
            await viewModel.loadExistingOffice()
        }
        .onChange(of: viewModel.coordinate) { _, newCoordinate in
            guard let newCoordinate else { return }
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: newCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsOfficeView()
    }
}
