import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var selectedDate = Date()
    @Published var currentMonth = Date()
    @Published var isLoading = false
    @Published var error: String?

    private let service = CalendarService.shared

    var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            guard let date = event.startDate else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }.sorted { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
    }

    func datesWithEvents() -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(events.compactMap { event in
            guard let date = event.startDate else { return nil }
            return formatter.string(from: date)
        })
    }

    func loadEvents(workspaceId: Int) async {
        isLoading = true
        error = nil
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

        do {
            events = try await service.getEvents(
                workspaceId: workspaceId,
                start: startOfMonth,
                end: endOfMonth
            )
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createEvent(
        workspaceId: Int,
        title: String,
        description: String,
        date: Date,
        allDay: Bool,
        color: String
    ) async {
        let formatter = ISO8601DateFormatter()
        let request = CreateEventRequest(
            workspace: workspaceId,
            title: title,
            description: description,
            startDatetime: formatter.string(from: date),
            endDatetime: formatter.string(from: date.addingTimeInterval(3600)),
            allDay: allDay,
            color: color
        )
        do {
            let newEvent = try await service.createEvent(request)
            events.append(newEvent)
            events.sort { ($0.startDate ?? Date()) < ($1.startDate ?? Date()) }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteEvent(id: String) async {
        do {
            try await service.deleteEvent(id: id)
            events.removeAll { $0.id == id }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
