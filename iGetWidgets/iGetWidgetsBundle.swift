import WidgetKit
import SwiftUI

@main
struct iGetWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        TasksWidget()
        FocusWidget()
        CountdownWidget()
        NotesWidget()
        CalendarWidget()
        HabitsWidget()
    }
}
