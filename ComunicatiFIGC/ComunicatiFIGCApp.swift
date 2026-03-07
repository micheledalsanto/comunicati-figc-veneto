import SwiftUI
import BackgroundTasks

@main
struct ComunicatiFIGCApp: App {
    @StateObject private var store = ComunicatoStore()
    @Environment(\.scenePhase) private var scenePhase

    static let taskID = "it.figcveneto.comunicati.refresh"

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskID,
            using: nil
        ) { task in
            Self.handleRefresh(task as! BGAppRefreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Self.scheduleRefresh()
            }
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func handleRefresh(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        let op = Task {
            let newItems = await ComunicatoFetcher.checkForNew()
            if !newItems.isEmpty {
                await NotificationManager.sendNotification(for: newItems)
            }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { op.cancel() }
    }
}
