import GleanFeed
import SwiftUI

/// Boring on purpose: one screen that exercises every public SDK method so a
/// maintainer can eyeball the whole surface in the simulator.
struct ContentView: View {
    @State private var userId = ""
    @State private var email = ""
    @State private var signature = ""
    @State private var status = "Anonymous"
    @State private var unread = 0
    @State private var diagnosticsStatus = "—"

    @State private var showFeedback = false
    @State private var showRoadmap = false
    @State private var showChangelog = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Identity")) {
                    TextField("User ID", text: $userId).autocapitalization(.none)
                    TextField("Email (optional)", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    TextField("Signature (from your backend)", text: $signature)
                        .autocapitalization(.none)
                    Button("Identify", action: identify)
                    Button("Logout", action: logout)
                    Text("Status: \(status)").foregroundColor(.secondary)
                }

                Section(header: Text("Surfaces")) {
                    Button("Show Feedback") { showFeedback = true }
                    Button("Show Roadmap") { showRoadmap = true }
                    Button("Show Changelog") { showChangelog = true }
                }

                Section(header: Text("Diagnostics")) {
                    Button("Send diagnostics", action: sendDiagnostics)
                    Text("Last: \(diagnosticsStatus)").foregroundColor(.secondary)
                }

                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Unread")
                        Spacer()
                        Text("\(unread)").foregroundColor(.secondary)
                    }
                    Button("Refresh unread", action: refreshUnread)
                }
            }
            .navigationTitle("Glean Feed Sample")
            .gleanFeedFeedback(isPresented: $showFeedback)
            .gleanFeedRoadmap(isPresented: $showRoadmap)
            .gleanFeedChangelog(isPresented: $showChangelog)
        }
    }

    private func identify() {
        Task { @MainActor in
            do {
                try await GleanFeed.identify(
                    userId: userId,
                    email: email.isEmpty ? nil : email,
                    signature: signature
                )
                status = "Signed in as \(userId)"
                refreshUnread()
            } catch {
                status = "Identify failed: \(error.localizedDescription)"
            }
        }
    }

    private func logout() {
        GleanFeed.logout()
        status = "Anonymous"
        unread = 0
    }

    private func sendDiagnostics() {
        Task { @MainActor in
            do {
                try await GleanFeed.sendDiagnostics()
                diagnosticsStatus = "sent"
            } catch {
                diagnosticsStatus = "failed"
            }
        }
    }

    private func refreshUnread() {
        Task { @MainActor in
            unread = (try? await GleanFeed.unreadCount()) ?? 0
        }
    }
}
