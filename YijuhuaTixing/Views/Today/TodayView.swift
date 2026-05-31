import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.remindAt, order: .forward) private var reminders: [Reminder]
    @State private var viewModel = TodayViewModel()
    @State private var showConfirmSheet = false
    @State private var showPermissionSheet = false
    @State private var permissionPendingReminder: ParsedReminder?
    @State private var showSettings = false
    @State private var snoozeTarget: Reminder?
    @State private var deleteTarget: Reminder?
    @State private var deleteUndoReminder: Reminder?
    @State private var deleteUndoStatus: ReminderStatus?
    @State private var selectedReminder: Reminder?
    @State private var notificationNoticeMessage: String?
    @State private var actionNoticeMessage: String?
    @State private var actionNoticeToken: UUID?
    @AppStorage("morningDefaultHour") private var morningDefaultHour = ParserSettings.default.morningDefaultHour
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = ParserSettings.default.eveningDefaultHour

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header

                QuickInputBar(text: $viewModel.inputText, isParsing: viewModel.isParsing) {
                    viewModel.submit(settings: parserSettings)
                    showConfirmSheet = viewModel.parsedReminder != nil
                }

                if let notificationNoticeMessage {
                    notificationNoticeBanner(message: notificationNoticeMessage)
                }

                if let actionNoticeMessage {
                    actionNoticeBanner(message: actionNoticeMessage)
                }

                if let deleteUndoReminder {
                    undoDeleteBanner(reminder: deleteUndoReminder)
                }

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }

                if todayReminders.isEmpty {
                    emptyState
                } else {
                    summary
                    reminderList
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationDestination(isPresented: isDetailPresented) {
                if let selectedReminder {
                    TaskDetailView(reminder: selectedReminder)
                }
            }
            .sheet(isPresented: $showConfirmSheet) {
                if let parsed = viewModel.parsedReminder {
                    ConfirmReminderSheet(parsedReminder: parsed, settings: parserSettings) { confirmed in
                        confirmReminder(confirmed)
                    } onCancel: {
                        showConfirmSheet = false
                    }
                }
            }
            .sheet(isPresented: $showPermissionSheet) {
                NotificationPermissionSheet {
                    requestPermissionAndCreate()
                } onLater: {
                    if let parsed = permissionPendingReminder {
                        createReminder(from: parsed, scheduleNotification: false)
                    }
                    showPermissionSheet = false
                }
            }
            .sheet(item: $snoozeTarget) { reminder in
                SnoozeActionSheet { option in
                    snooze(reminder, option: option)
                    snoozeTarget = nil
                } onCancel: {
                    snoozeTarget = nil
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .confirmationDialog("删除这个提醒？", isPresented: isDeleteConfirmationPresented, titleVisibility: .visible) {
                Button("删除提醒", role: .destructive) {
                    if let deleteTarget {
                        delete(deleteTarget)
                    }
                    deleteTarget = nil
                }
                Button("取消", role: .cancel) {
                    deleteTarget = nil
                }
            } message: {
                Text("删除后不会再收到这条提醒。")
            }
            .onChange(of: viewModel.inputText) { _, _ in
                if viewModel.errorMessage != nil {
                    viewModel.errorMessage = nil
                }
                if notificationNoticeMessage != nil {
                    notificationNoticeMessage = nil
                }
                if actionNoticeMessage != nil {
                    actionNoticeMessage = nil
                    actionNoticeToken = nil
                }
            }
            .onAppear(perform: configureNotificationRouter)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今天")
                    .font(.largeTitle.weight(.semibold))
                Text(DateFormatterProvider.dayFormatter.string(from: Date()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("关闭错误提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private func notificationNoticeBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.blue)
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("去设置") {
                openSystemSettings()
            }
            .font(.footnote.weight(.semibold))

            Button {
                notificationNoticeMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("关闭通知提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    private func actionNoticeBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 1)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button {
                actionNoticeMessage = nil
                actionNoticeToken = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("关闭操作提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }

    private func undoDeleteBanner(reminder: Reminder) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text("已删除「\(reminder.title)」")
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button("撤销") {
                undoDelete()
            }
            .font(.footnote.weight(.semibold))

            Button {
                deleteUndoReminder = nil
                deleteUndoStatus = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("关闭删除提示")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("一句话提醒")
                .font(.title2.weight(.semibold))
            Text("说一句，到点提醒。")
                .foregroundStyle(.secondary)
            Text("试试：10分钟后提醒我喝水")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("今天还没有提醒")
                .font(.headline)
                .padding(.top, 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var summary: some View {
        HStack(spacing: 8) {
            Text("\(activeReminderCount) 个待提醒")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if overdueReminderCount > 0 {
                Text("\(overdueReminderCount) 个已过时间")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            if snoozedReminderCount > 0 {
                Text("\(snoozedReminderCount) 个已延后")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
        }
    }

    private var reminderList: some View {
        List {
            if !overdueReminders.isEmpty {
                Section {
                    ForEach(overdueReminders) { reminder in
                        reminderRow(for: reminder)
                    }
                } header: {
                    sectionHeader(
                        title: "已过时间",
                        count: overdueReminders.count,
                        systemImage: "exclamationmark.circle.fill",
                        tint: .orange
                    )
                }
            }

            if !snoozedTodayReminders.isEmpty {
                Section {
                    ForEach(snoozedTodayReminders) { reminder in
                        reminderRow(for: reminder)
                    }
                } header: {
                    sectionHeader(
                        title: "已延后",
                        count: snoozedTodayReminders.count,
                        systemImage: "clock.arrow.circlepath",
                        tint: .blue
                    )
                }
            }

            if !upcomingTodayReminders.isEmpty {
                Section {
                    ForEach(upcomingTodayReminders) { reminder in
                        reminderRow(for: reminder)
                    }
                } header: {
                    sectionHeader(
                        title: "今天稍后",
                        count: upcomingTodayReminders.count,
                        systemImage: "tray.full",
                        tint: .secondary
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(2)
    }

    private func sectionHeader(title: String, count: Int, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: systemImage)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tint.opacity(0.12), in: Capsule())
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .textCase(nil)
        .padding(.top, 8)
        .accessibilityLabel("\(title)，\(count) 个提醒")
    }

    private var todayReminders: [Reminder] {
        let calendar = Calendar.current
        return reminders.filter { reminder in
            !reminder.isDeleted &&
            !reminder.isCompleted &&
            (calendar.isDateInToday(reminder.remindAt) || reminder.remindAt < Date())
        }
    }

    private var overdueReminders: [Reminder] {
        todayReminders.filter { $0.remindAt < Date() }
    }

    private var snoozedTodayReminders: [Reminder] {
        todayReminders.filter { $0.remindAt >= Date() && $0.status == .snoozed }
    }

    private var upcomingTodayReminders: [Reminder] {
        todayReminders.filter { $0.remindAt >= Date() && $0.status != .snoozed }
    }

    private var activeReminderCount: Int {
        overdueReminders.count + snoozedTodayReminders.count + upcomingTodayReminders.count
    }

    private var overdueReminderCount: Int {
        overdueReminders.count
    }

    private var snoozedReminderCount: Int {
        snoozedTodayReminders.count
    }

    private var parserSettings: ParserSettings {
        var settings = ParserSettings.default
        settings.morningDefaultHour = morningDefaultHour
        settings.eveningDefaultHour = eveningDefaultHour
        return settings
    }

    @ViewBuilder
    private func reminderRow(for reminder: Reminder) -> some View {
        ReminderRow(reminder: reminder) {
            complete(reminder)
        } onDelete: {
            deleteTarget = reminder
        } onSnooze: {
            snoozeTarget = reminder
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedReminder = reminder
        }
    }

    private var isDetailPresented: Binding<Bool> {
        Binding {
            selectedReminder != nil
        } set: { isPresented in
            if !isPresented {
                selectedReminder = nil
            }
        }
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding {
            deleteTarget != nil
        } set: { isPresented in
            if !isPresented {
                deleteTarget = nil
            }
        }
    }

    private func confirmReminder(_ parsed: ParsedReminder) {
        Task {
            let status = await NotificationService.shared.authorizationStatus()
            if status == .notDetermined {
                permissionPendingReminder = parsed
                showConfirmSheet = false
                showPermissionSheet = true
            } else {
                createReminder(from: parsed, scheduleNotification: status == .authorized || status == .provisional)
            }
        }
    }

    private func requestPermissionAndCreate() {
        Task {
            do {
                let granted = try await NotificationService.shared.requestAuthorization()
                if let parsed = permissionPendingReminder {
                    createReminder(from: parsed, scheduleNotification: granted)
                }
            } catch {
                if let parsed = permissionPendingReminder {
                    createReminder(from: parsed, scheduleNotification: false)
                }
            }
            showPermissionSheet = false
        }
    }

    private func createReminder(from parsed: ParsedReminder, scheduleNotification: Bool) {
        Task {
            let store = ReminderStore(context: modelContext)
            do {
                let reminder = try await store.create(from: parsed, scheduleNotification: scheduleNotification)
                Haptics.success()
                deleteUndoReminder = nil
                deleteUndoStatus = nil
                viewModel.resetAfterCreate()
                showConfirmSheet = false
                permissionPendingReminder = nil
                if scheduleNotification {
                    notificationNoticeMessage = nil
                    showActionNotice("已创建「\(reminder.title)」")
                } else {
                    clearActionNotice()
                    notificationNoticeMessage = "已保存提醒，但通知权限未开启，到点不会推送。可前往系统设置开启通知。"
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func complete(_ reminder: Reminder) {
        Task {
            do {
                try await ReminderStore(context: modelContext).complete(reminder)
                Haptics.success()
                deleteUndoReminder = nil
                deleteUndoStatus = nil
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func delete(_ reminder: Reminder) {
        do {
            let previousStatus = reminder.status
            try ReminderStore(context: modelContext).delete(reminder)
            deleteUndoReminder = reminder
            deleteUndoStatus = previousStatus
            notificationNoticeMessage = nil
            clearActionNotice()
            Haptics.success()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }

    private func snooze(_ reminder: Reminder, option: SnoozeOption) {
        Task {
            do {
                try await ReminderStore(context: modelContext).snooze(reminder, option: option, settings: parserSettings)
                Haptics.success()
                deleteUndoReminder = nil
                deleteUndoStatus = nil
                notificationNoticeMessage = nil
                showActionNotice(DateFormatterProvider.snoozedLabel(for: reminder.remindAt))
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func undoDelete() {
        guard let reminder = deleteUndoReminder else {
            return
        }

        let restoreStatus = deleteUndoStatus ?? .pending
        Task {
            do {
                try await ReminderStore(context: modelContext).restoreDeleted(reminder, status: restoreStatus)
                deleteUndoReminder = nil
                deleteUndoStatus = nil
                Haptics.success()
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func configureNotificationRouter() {
        let store = ReminderStore(context: modelContext)
        NotificationActionRouter.shared.configure { id in
            Task { @MainActor in
                if let reminder = try? store.reminder(id: id) {
                    try? await store.complete(reminder)
                }
            }
        } onSnooze: { id, option in
            Task { @MainActor in
                if let reminder = try? store.reminder(id: id) {
                    try? await store.snooze(reminder, option: option, settings: ParserSettings.fromUserDefaults())
                }
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func showActionNotice(_ message: String) {
        let token = UUID()
        actionNoticeMessage = message
        actionNoticeToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard actionNoticeToken == token else {
                return
            }
            clearActionNotice()
        }
    }

    private func clearActionNotice() {
        actionNoticeMessage = nil
        actionNoticeToken = nil
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewContainer.inMemory)
}
