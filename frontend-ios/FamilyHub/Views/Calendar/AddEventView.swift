import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let eventToEdit: CalendarEvent?

    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var allDay = false
    @State private var selectedColor = "#6366f1"

    let colorOptions = ["#6366f1", "#ef4444", "#22c55e", "#f59e0b", "#3b82f6", "#ec4899"]

    init(eventToEdit: CalendarEvent? = nil) {
        self.eventToEdit = eventToEdit
    }

    private var isEditMode: Bool { eventToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3)
                }

                Section("Date & Time") {
                    Toggle("All Day", isOn: $allDay)
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: allDay ? .date : [.date, .hourAndMinute]
                    )
                }

                Section("Color") {
                    HStack(spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .indigo)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                        .padding(-2)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditMode ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                        Task {
                            if let event = eventToEdit {
                                await calendarViewModel.updateEvent(
                                    id: event.id,
                                    workspaceId: workspaceId,
                                    title: title,
                                    description: description,
                                    date: date,
                                    allDay: allDay,
                                    color: selectedColor
                                )
                            } else {
                                await calendarViewModel.createEvent(
                                    workspaceId: workspaceId,
                                    title: title,
                                    description: description,
                                    date: date,
                                    allDay: allDay,
                                    color: selectedColor
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let event = eventToEdit {
                    title = event.title
                    description = event.description ?? ""
                    date = event.startDate ?? Date()
                    allDay = event.allDay
                    selectedColor = event.color ?? "#6366f1"
                }
            }
        }
    }
}
