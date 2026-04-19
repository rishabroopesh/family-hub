import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showAddEvent = false
    @State private var eventBeingEdited: CalendarEvent?
    @State private var eventBeingViewed: CalendarEvent?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MonthCalendarGrid(
                    currentMonth: $calendarViewModel.currentMonth,
                    selectedDate: $calendarViewModel.selectedDate,
                    datesWithEvents: calendarViewModel.datesWithEvents()
                )
                .onChange(of: calendarViewModel.currentMonth) {
                    guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                    Task { await calendarViewModel.loadEvents(workspaceId: workspaceId) }
                }

                Divider()

                // Events for selected date
                let dateEvents = calendarViewModel.eventsForSelectedDate
                if dateEvents.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "calendar.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No events on this day")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(dateEvents) { event in
                        EventRowView(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if event.isClassroomEvent {
                                    eventBeingViewed = event
                                } else {
                                    eventBeingEdited = event
                                }
                            }
                            .swipeActions {
                                if !event.isClassroomEvent {
                                    Button(role: .destructive) {
                                        Task { await calendarViewModel.deleteEvent(id: event.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddEvent = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventView()
                    .environmentObject(calendarViewModel)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $eventBeingEdited) { event in
                AddEventView(eventToEdit: event)
                    .environmentObject(calendarViewModel)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $eventBeingViewed) { event in
                EventDetailView(event: event)
            }
            .onAppear {
                guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                Task { await calendarViewModel.loadEvents(workspaceId: workspaceId) }
            }
            .onChange(of: authViewModel.currentWorkspaceId) { _, newId in
                guard let workspaceId = newId else { return }
                Task { await calendarViewModel.loadEvents(workspaceId: workspaceId) }
            }
        }
    }
}

struct MonthCalendarGrid: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let datesWithEvents: Set<String>

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(currentMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)

            // Day headers
            HStack {
                ForEach(dayNames, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvent: datesWithEvents.contains(dateFormatter.string(from: date))
                        )
                        .onTapGesture { selectedDate = date }
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func daysInMonth() -> [Date?] {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in 1...daysInMonth {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: startOfMonth))
        }
        return days
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvent: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.day())
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isSelected ? .white : (isToday ? .purple : .primary))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.purple : Color.clear)
                .clipShape(Circle())

            Circle()
                .fill(hasEvent ? (isSelected ? Color.white : Color.purple) : Color.clear)
                .frame(width: 4, height: 4)
        }
    }
}

struct EventRowView: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            if event.isClassroomEvent {
                GradientBar()
                    .frame(height: 44)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: event.displayColor) ?? .green)
                    .frame(width: 4, height: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    if event.isClassroomEvent {
                        Image(systemName: "graduationcap.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accentGradient)
                    }
                }
                if let start = event.startDate, !event.allDay {
                    Text(start, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let desc = event.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: event.displayColor) ?? .blue)
                            .frame(width: 4)
                        Text(event.title)
                            .font(.headline)
                    }
                    .listRowSeparator(.hidden)
                }

                Section("Due") {
                    if event.allDay {
                        if let date = event.startDate {
                            Text(date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        }
                        Text("All day")
                            .foregroundColor(.secondary)
                    } else if let start = event.startDate {
                        Text(start, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        Text(start, format: .dateTime.hour().minute())
                    }
                }

                if let desc = event.description, !desc.isEmpty {
                    Section("Details") {
                        Text(desc.replacingOccurrences(of: "[demo-seed]", with: "").trimmingCharacters(in: .whitespaces))
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

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
