import SwiftUI
import AuthenticationServices

struct ClassroomView: View {
    @EnvironmentObject var classroomViewModel: ClassroomViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            Group {
                if !classroomViewModel.googleConnected {
                    NotConnectedView()
                        .environmentObject(classroomViewModel)
                } else {
                    ConnectedClassroomView()
                        .environmentObject(classroomViewModel)
                }
            }
            .navigationTitle("Classroom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if classroomViewModel.googleConnected {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: InsightsView()) {
                            Image(systemName: "sparkles")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            Task { await classroomViewModel.triggerSync() }
                        }) {
                            if classroomViewModel.isSyncing {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(classroomViewModel.isSyncing)
                    }
                }
            }
            .onAppear {
                Task {
                    await classroomViewModel.checkGoogleStatus()
                    if classroomViewModel.googleConnected {
                        await classroomViewModel.loadCourses()
                        await classroomViewModel.loadSyncStatus()
                    }
                }
            }
        }
    }
}

struct NotConnectedView: View {
    @EnvironmentObject var classroomViewModel: ClassroomViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.indigo)
                Text("Connect Google Classroom")
                    .font(.title2.bold())
                Text("Link your Google account to automatically sync courses, assignments, and due dates.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: connectGoogle) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect Google Account")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                if let error = classroomViewModel.error {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 140)
            .frame(maxWidth: .infinity)
        }
    }

    private func connectGoogle() {
        Task {
            guard let urlString = await classroomViewModel.getGoogleConnectURL(),
                  let url = URL(string: urlString) else { return }

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "familyhub"
            ) { callbackURL, error in
                if error == nil {
                    Task {
                        await classroomViewModel.checkGoogleStatus()
                        if classroomViewModel.googleConnected {
                            await classroomViewModel.loadCourses()
                        }
                    }
                }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
}

struct ConnectedClassroomView: View {
    @EnvironmentObject var classroomViewModel: ClassroomViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Sync status banner
            if let log = classroomViewModel.syncStatus {
                HStack {
                    Text(log.statusEmoji)
                    Text("Last synced: \(log.startedAt.prefix(10))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(log.coursesSynced) courses, \(log.courseworkSynced) assignments")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            }

            if classroomViewModel.isLoading && classroomViewModel.courses.isEmpty {
                ProgressView("Loading courses...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if classroomViewModel.courses.isEmpty {
                ContentUnavailableView(
                    "No Courses Found",
                    systemImage: "book",
                    description: Text("Tap the sync button to fetch your courses.")
                )
            } else {
                List(classroomViewModel.courses) { course in
                    NavigationLink(destination: CourseDetailView(course: course)
                        .environmentObject(classroomViewModel)) {
                        CourseRowView(course: course)
                    }
                }
            }
        }
        .refreshable {
            await classroomViewModel.triggerSync()
        }
    }
}

struct CourseRowView: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.name)
                .fontWeight(.semibold)
            HStack {
                if let section = course.section, !section.isEmpty {
                    Text(section)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let teacher = course.teacherName, !teacher.isEmpty {
                    Text("• \(teacher)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
