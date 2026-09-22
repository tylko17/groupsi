import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isLoggedIn {
                LoggedInView()
            } else {
                SignInView()
            }
        }
        .frame(width: 300)
        .task {
            if state.isLoggedIn {
                await state.refreshLeaderboard()
            }
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("StudyBuddy", systemImage: "book.closed.fill")
                .font(.headline)
            Text("Pick a username to start tracking study sessions and join the leaderboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("username", text: $state.usernameInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { Task { await state.register() } }
            if let error = state.registerError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Button {
                Task { await state.register() }
            } label: {
                if state.isRegistering {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || state.isRegistering)

            Divider().padding(.vertical, 4)
            Button("Quit StudyBuddy") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

struct LoggedInView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            sessionControl
            Divider()
            LeaderboardSection()
            Divider()
            CompareSection()
            Divider()
            footer
        }
        .padding(14)
    }

    private var header: some View {
        HStack {
            Label(state.username ?? "", systemImage: "book.closed.fill")
                .font(.headline)
            Spacer()
            if let totals = state.myTotals {
                Text(formatDuration(totals.totalSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sessionControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            if state.isSessionActive {
                Text(formatDuration(state.elapsedSeconds))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Button {
                state.toggleSession()
            } label: {
                Label(
                    state.isSessionActive ? "Stop Studying" : "Start Studying",
                    systemImage: state.isSessionActive ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isSessionActive ? .red : .accentColor)
        }
    }

    private var footer: some View {
        HStack {
            Button("Sign Out") { state.signOut() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct LeaderboardSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Leaderboard").font(.subheadline).bold()
                Spacer()
                Picker("", selection: $state.leaderboardPeriod) {
                    ForEach(LeaderboardPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .onChange(of: state.leaderboardPeriod) { _ in
                    Task { await state.refreshLeaderboard() }
                }
            }

            if state.isLoadingLeaderboard {
                ProgressView().controlSize(.small)
            } else if let error = state.leaderboardError {
                Text(error).font(.caption2).foregroundStyle(.red)
            } else if state.leaderboard.isEmpty {
                Text("No sessions logged yet. Be the first!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.leaderboard.prefix(5)) { entry in
                    HStack {
                        Text("\(entry.rank).")
                            .frame(width: 20, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(entry.username)
                            .fontWeight(entry.username == state.username ? .bold : .regular)
                        Spacer()
                        Text(formatDuration(entry.totalSeconds))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            Button("Refresh") { Task { await state.refreshLeaderboard() } }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.accentColor)
        }
    }
}

struct CompareSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Head to Head").font(.subheadline).bold()
            HStack {
                TextField("their username", text: $state.compareTarget)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit { Task { await state.runCompare() } }
                Button("Go") { Task { await state.runCompare() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            if let error = state.compareError {
                Text(error).font(.caption2).foregroundStyle(.red)
            }

            if let result = state.compareResult {
                let leader = result.a.totalSeconds >= result.b.totalSeconds ? result.a.username : result.b.username
                VStack(spacing: 4) {
                    compareRow(side: result.a, isLeader: leader == result.a.username)
                    compareRow(side: result.b, isLeader: leader == result.b.username)
                }
            }
        }
    }

    private func compareRow(side: CompareSide, isLeader: Bool) -> some View {
        HStack {
            if isLeader {
                Image(systemName: "crown.fill").foregroundStyle(.yellow).font(.caption2)
            }
            Text(side.username).fontWeight(isLeader ? .bold : .regular)
            Spacer()
            Text(formatDuration(side.totalSeconds)).foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
