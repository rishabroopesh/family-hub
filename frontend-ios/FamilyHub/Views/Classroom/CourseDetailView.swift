import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var classroomViewModel: ClassroomViewModel

    var coursework: [Coursework] {
        (classroomViewModel.courseworkByCourse[course.id] ?? [])
            .sorted { a, b in
                guard let da = a.dueDateTime, let db = b.dueDateTime else { return a.dueDate != nil }
                return da < db
            }
    }

    var body: some View {
        List {
            // Course info
            Section {
                if let section = course.section, !section.isEmpty {
                    LabeledContent("Section", value: section)
                }
                if let teacher = course.teacherName, !teacher.isEmpty {
                    LabeledContent("Teacher", value: teacher)
                }
                if let link = course.alternateLink, !link.isEmpty, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("Open in Google Classroom", systemImage: "arrow.up.right.square")
                    }
                }
            }

            // Assignments
            Section("Assignments") {
                if coursework.isEmpty {
                    Text("No assignments found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(coursework) { cw in
                        CourseworkRowView(coursework: cw)
                    }
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await classroomViewModel.loadCoursework(for: course.id) }
        }
    }
}

struct CourseworkRowView: View {
    let coursework: Coursework

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(coursework.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Spacer()
                if let link = coursework.alternateLink, !link.isEmpty, let url = URL(string: link) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                if let due = coursework.dueDateFormatted {
                    Label(due, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(coursework.isOverdue ? .red : .secondary)
                } else {
                    Text("No due date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let pts = coursework.maxPoints {
                    Label("\(Int(pts)) pts", systemImage: "star")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if coursework.isOverdue {
                Label("Overdue", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
