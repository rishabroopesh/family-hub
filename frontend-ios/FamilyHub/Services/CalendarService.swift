import Foundation

final class CalendarService {
    static let shared = CalendarService()
    private let client = APIClient.shared

    func getEvents(workspaceId: Int, start: Date, end: Date) async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        let endpoint = "\(Endpoints.calendarEvents)?workspace=\(workspaceId)&start=\(startStr)&end=\(endStr)"
        return try await client.requestList(endpoint)
    }

    func createEvent(_ request: CreateEventRequest) async throws -> CalendarEvent {
        let body = try JSONEncoder().encode(request)
        return try await client.request(Endpoints.calendarEvents, method: "POST", body: body)
    }

    func updateEvent(id: String, request: CreateEventRequest) async throws -> CalendarEvent {
        let body = try JSONEncoder().encode(request)
        return try await client.request(Endpoints.calendarEvent(id), method: "PATCH", body: body)
    }

    func deleteEvent(id: String) async throws {
        try await client.requestVoid(Endpoints.calendarEvent(id), method: "DELETE")
    }
}
