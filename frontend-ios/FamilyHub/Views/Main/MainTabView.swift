import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var classroomViewModel = ClassroomViewModel()
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var pagesViewModel = PagesViewModel()

    var body: some View {
        TabView {
            PagesListView()
                .tabItem { Label("Pages", systemImage: "book.fill") }
                .environmentObject(pagesViewModel)
                .environmentObject(authViewModel)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .environmentObject(calendarViewModel)
                .environmentObject(authViewModel)

            ClassroomView()
                .tabItem { Label("Classroom", systemImage: "graduationcap.fill") }
                .environmentObject(classroomViewModel)
                .environmentObject(authViewModel)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .environmentObject(authViewModel)
                .environmentObject(classroomViewModel)
        }
        .tint(.indigo)
    }
}
