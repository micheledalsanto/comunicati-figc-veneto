import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ComunicatoStore

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.comunicati.isEmpty {
                    ProgressView("Caricamento...")
                } else if let error = store.error, store.comunicati.isEmpty {
                    ContentUnavailableView {
                        Label("Errore", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Riprova") { Task { await store.refresh() } }
                            .buttonStyle(.bordered)
                    }
                } else {
                    List(store.comunicati) { item in
                        ComunicatoRow(comunicato: item)
                    }
                    .refreshable { await store.refresh() }
                }
            }
            .navigationTitle("Comunicati")
            .task {
                await NotificationManager.requestAuthorization()
                let _ = await store.checkForNew()
            }
        }
    }
}

struct ComunicatoRow: View {
    let comunicato: Comunicato
    @State private var showActions = false

    var body: some View {
        Button { showActions = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(comunicato.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !comunicato.date.isEmpty {
                        Text(comunicato.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "doc.fill")
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 2)
        }
        .confirmationDialog(comunicato.title, isPresented: $showActions) {
            if let url = comunicato.viewURL {
                Button("Visualizza PDF") {
                    UIApplication.shared.open(url)
                }
            }
            if let url = comunicato.downloadURL {
                ShareLink(item: url) {
                    Text("Condividi / Scarica")
                }
            }
        }
    }
}
