import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var classroomViewModel: ClassroomViewModel
    @State private var selectedCoursework: Coursework?

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
            }

            // Assignments
            Section("Assignments") {
                if coursework.isEmpty {
                    Text("No assignments found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(coursework) { cw in
                        CourseworkRowView(coursework: cw)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCoursework = cw
                            }
                    }
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task { await classroomViewModel.loadCoursework(for: course.id) }
        }
        .sheet(item: $selectedCoursework) { cw in
            CourseworkDetailView(coursework: cw, courseName: course.name)
        }
    }
}

struct CourseworkRowView: View {
    let coursework: Coursework

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coursework.title)
                .fontWeight(.medium)
                .lineLimit(2)

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
                    Text("\(Int(pts)) pts")
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

struct CourseworkDetailView: View {
    let coursework: Coursework
    let courseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(coursework.title)
                        .font(.headline)
                }

                Section("Course") {
                    Text(courseName)
                }

                Section("Due") {
                    if let due = coursework.dueDateFormatted {
                        Text(due)
                        if coursework.isOverdue {
                            Label("Overdue", systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("No due date")
                            .foregroundColor(.secondary)
                    }
                    if let time = coursework.dueTime {
                        Text(time)
                    }
                }

                if let pts = coursework.maxPoints {
                    Section("Points") {
                        Text("\(Int(pts))")
                    }
                }

                if let desc = coursework.description, !desc.isEmpty {
                    Section("Details") {
                        Text(desc)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
