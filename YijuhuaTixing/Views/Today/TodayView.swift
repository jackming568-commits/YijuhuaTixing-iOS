import Combine
import SwiftData
import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Reminder.remindAt, order: .forward) private var reminders: [Reminder]
    @State private var viewModel = TodayViewModel()
    @State private var speechInput = SpeechInputService()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var showConfirmSheet = false
    @State private var showPermissionSheet = false
    @State private var permissionPendingReminder: ParsedReminder?
    @State private var showSettings = false
    @State private var isMembershipCenterPresented = false
    @State private var membershipCenterMessage: String?
    @State private var membershipCenterSource = "feature_gate"
    @State private var snoozeTarget: Reminder?
    @State private var deleteTarget: Reminder?
    @State private var deleteUndoReminder: Reminder?
    @State private var deleteUndoStatus: ReminderStatus?
    @State private var deleteUndoToken: UUID?
    @State private var selectedReminder: Reminder?
    @State private var notificationNoticeMessage: String?
    @State private var actionNoticeMessage: String?
    @State private var actionNoticeToken: UUID?
    @State private var currentDate = Date()
    @State private var isSearchPresented = false
    @State private var reminderSearchText = ""
    @State private var selectedTagFilter: ReminderTag?
    @State private var didRefreshScheduledNotifications = false
    @FocusState private var isReminderSearchFocused: Bool
    @AppStorage("didShowNotificationPreviewHint") private var didShowNotificationPreviewHint = false
    @AppStorage("morningDefaultHour") private var morningDefaultHour = ParserSettings.default.morningDefaultHour
    @AppStorage("morningDefaultMinute") private var morningDefaultMinute = ParserSettings.default.morningDefaultMinute
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = ParserSettings.default.eveningDefaultHour
    @AppStorage("eveningDefaultMinute") private var eveningDefaultMinute = ParserSettings.default.eveningDefaultMinute

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                header

                QuickInputBar(
                    text: $viewModel.inputText,
                    isParsing: viewModel.isParsing,
                    isListening: speechInput.isListening,
                    voiceMessage: speechInput.statusMessage,
                    isVoiceMessageError: speechInput.isShowingError
                ) {
                    toggleQuickVoiceInput()
                } onSubmit: {
                    submitQuickInput()
                }

                if isSearchPresented {
                    reminderSearchBar
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

                if baseActiveReminders.isEmpty {
                    emptyState
                } else {
                    summary
                    tagFilterBar
                    if activeReminders.isEmpty {
                        searchEmptyState
                    } else {
                        reminderList
                    }
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
            .sheet(isPresented: $isMembershipCenterPresented) {
                NavigationStack {
                    MembershipCenterView(
                        subscriptionStore: subscriptionStore,
                        promptMessage: membershipCenterMessage,
                        source: membershipCenterSource
                    )
                }
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
            .onChange(of: speechInput.transcript) { _, transcript in
                let normalizedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedTranscript.isEmpty {
                    viewModel.inputText = normalizedTranscript
                }
            }
            .onAppear {
                configureNotificationRouter()
                refreshCurrentDate()
                refreshScheduledNotificationContentIfNeeded()
            }
            .task {
                await subscriptionStore.refreshEntitlement()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshCurrentDate()
                    Task {
                        await subscriptionStore.refreshEntitlement()
                    }
                }
            }
            .onChange(of: isMembershipCenterPresented) { _, isPresented in
                if !isPresented {
                    Task {
                        await subscriptionStore.refreshEntitlement()
                    }
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                currentDate = date
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今天")
                    .font(.largeTitle.weight(.semibold))
                Text(DateFormatterProvider.dayFormatter.string(from: currentDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                toggleSearch()
            } label: {
                Image(systemName: isSearchPresented ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isSearchPresented ? .blue : .secondary)
            .accessibilityLabel(isSearchPresented ? "关闭搜索" : "搜索未来任务")

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

    private var reminderSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索未来任务关键词", text: $reminderSearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isReminderSearchFocused)
                .submitLabel(.search)

            if !reminderSearchText.isEmpty {
                Button {
                    reminderSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
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
                clearDeleteUndo()
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

    private var searchEmptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("没有匹配的未来任务")
                .font(.headline)
            Text("换个关键词试试，可以搜任务内容、原始输入或提醒日期。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var summary: some View {
        HStack(spacing: 8) {
            Text(isFilteringReminders ? "筛选到 \(activeReminderCount) 个待提醒" : "\(activeReminderCount) 个待提醒")
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

    private var tagFilterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button {
                    selectedTagFilter = nil
                    Haptics.lightTap()
                } label: {
                    allTagFilterChip
                }
                .buttonStyle(.plain)

                ForEach(tagFilterOptions) { option in
                    Button {
                        selectTagFilter(option.tag)
                    } label: {
                        ReminderTagChip(
                            tag: option.tag,
                            isSelected: selectedTagFilter == option.tag,
                            count: option.count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var allTagFilterChip: some View {
        HStack(spacing: 5) {
            Text("全部")
                .font(.caption.weight(.semibold))
            Text("\(searchFilteredReminders.count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color(uiColor: .systemBackground).opacity(0.72), in: Capsule())
        }
        .foregroundStyle(selectedTagFilter == nil ? .white : .blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(selectedTagFilter == nil ? Color.blue : Color.blue.opacity(0.12), in: Capsule())
    }

    private var reminderList: some View {
        List {
            ForEach(archiveSections) { section in
                Section {
                    ForEach(section.reminders) { reminder in
                        reminderRow(for: reminder)
                    }
                } header: {
                    PeriodSectionHeader(
                        title: section.period.title,
                        subtitle: section.period.rangeHint,
                        count: section.reminders.count,
                        systemImage: section.period.systemImage,
                        tint: tint(for: section.period)
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(2)
        .frame(maxHeight: .infinity)
    }

    private var activeReminders: [Reminder] {
        searchFilteredReminders.filter { reminder in
            guard let selectedTagFilter else {
                return true
            }
            return reminder.tag == selectedTagFilter
        }
    }

    private var searchFilteredReminders: [Reminder] {
        baseActiveReminders.filter { reminder in
            ReminderKeywordMatcher.matches(reminder: reminder, keyword: reminderSearchText)
        }
    }

    private var baseActiveReminders: [Reminder] {
        var seenIds = Set<UUID>()
        return reminders.filter { reminder in
            !reminder.isDeleted && !reminder.isCompleted && seenIds.insert(reminder.id).inserted
        }
    }

    private var archiveSections: [ReminderArchiveSection] {
        let grouped = Dictionary(grouping: activeReminders) { reminder in
            ReminderArchivePeriod.period(
                for: reminder.remindAt,
                now: currentDate,
                calendar: .current,
                includeOverdue: true
            )
        }

        return ReminderArchivePeriod.activeSectionOrder.compactMap { period in
            guard let reminders = grouped[period], !reminders.isEmpty else {
                return nil
            }
            return ReminderArchiveSection(period: period, reminders: reminders)
        }
    }

    private var activeReminderCount: Int {
        activeReminders.count
    }

    private var overdueReminderCount: Int {
        archiveSections.first { $0.period == .overdue }?.reminders.count ?? 0
    }

    private var snoozedReminderCount: Int {
        activeReminders.filter { $0.status == .snoozed }.count
    }

    private var isFilteringReminders: Bool {
        selectedTagFilter != nil || !reminderSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tagFilterOptions: [ReminderTagFilterOption] {
        let grouped = Dictionary(grouping: searchFilteredReminders) { $0.tag }
        return ReminderTag.allCases.compactMap { tag in
            guard let reminders = grouped[tag], !reminders.isEmpty else {
                return nil
            }
            return ReminderTagFilterOption(tag: tag, count: reminders.count)
        }
    }

    private var parserSettings: ParserSettings {
        var settings = ParserSettings.default
        settings.morningDefaultHour = morningDefaultHour
        settings.morningDefaultMinute = morningDefaultMinute
        settings.eveningDefaultHour = eveningDefaultHour
        settings.eveningDefaultMinute = eveningDefaultMinute
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

    private func submitQuickInput() {
        if speechInput.isListening {
            speechInput.stop()
        }

        viewModel.submit(settings: parserSettings)
        showConfirmSheet = viewModel.parsedReminder != nil
    }

    private func confirmReminder(_ parsed: ParsedReminder) {
        guard canCreateReminderUnderMembershipGate(source: "today_confirm_reminder") else {
            return
        }

        AppAnalytics.shared.track(.confirmationShown, properties: analyticsProperties(for: parsed, source: "quick_input"))

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
            guard canCreateReminderUnderMembershipGate(source: "today_create_reminder") else {
                return
            }

            let store = ReminderStore(context: modelContext)
            do {
                let reminder = try await store.create(from: parsed, scheduleNotification: scheduleNotification)
                Haptics.success()
                clearDeleteUndo()
                AppAnalytics.shared.track(.reminderCreated, properties: analyticsProperties(for: reminder, source: "quick_input"))
                viewModel.resetAfterCreate()
                showConfirmSheet = false
                permissionPendingReminder = nil
                if scheduleNotification {
                    notificationNoticeMessage = nil
                    await showNotificationPreviewHintIfNeeded()
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

    private func canCreateReminderUnderMembershipGate(source: String) -> Bool {
        let createdTodayCount = MembershipGate.createdTodayCount(reminders: reminders, now: currentDate)
        guard MembershipGate.canCreateReminder(
            hasProAccess: subscriptionStore.hasProAccess,
            reminders: reminders,
            now: currentDate
        ) else {
            showConfirmSheet = false
            showPermissionSheet = false
            permissionPendingReminder = nil
            let message = MembershipGate.dailyLimitMessage(createdTodayCount: createdTodayCount)
            viewModel.errorMessage = message
            showProFeatureBlocked(.reminderDailyLimit, source: source, message: message)
            return false
        }
        return true
    }

    private func toggleQuickVoiceInput() {
        Task {
            if speechInput.isListening {
                await speechInput.toggleListening()
                return
            }

            guard subscriptionStore.hasProAccess else {
                showProFeatureBlocked(.voiceInput, source: "today_quick_input")
                return
            }

            await speechInput.toggleListening()
        }
    }

    private func selectTagFilter(_ tag: ReminderTag) {
        guard subscriptionStore.hasProAccess else {
            showProFeatureBlocked(.tagFilter, source: "today_tag_filter")
            return
        }

        selectedTagFilter = tag
        Haptics.lightTap()
        AppAnalytics.shared.track(.tagFilterUsed, properties: ["tag": tag.rawValue])
    }

    private func showProFeatureBlocked(_ feature: ProFeature, source: String, message: String? = nil) {
        membershipCenterMessage = message ?? feature.blockedMessage
        membershipCenterSource = source
        AppAnalytics.shared.track(
            .proFeatureBlocked,
            properties: ["feature": feature.rawValue, "source": source]
        )
        Haptics.warning()
        isMembershipCenterPresented = true
    }

    private func complete(_ reminder: Reminder) {
        Task {
            do {
                try await ReminderStore(context: modelContext).complete(reminder)
                Haptics.success()
                clearDeleteUndo()
                AppAnalytics.shared.track(
                    .reminderCompleted,
                    properties: ["source": "today", "is_overdue": "\(reminder.remindAt < currentDate)"]
                )
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
            showDeleteUndo(reminder, previousStatus: previousStatus)
            notificationNoticeMessage = nil
            clearActionNotice()
            Haptics.success()
            AppAnalytics.shared.track(.reminderDeleted, properties: ["source": "today"])
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
                clearDeleteUndo()
                notificationNoticeMessage = nil
                showActionNotice(DateFormatterProvider.snoozedLabel(for: reminder.remindAt))
                AppAnalytics.shared.track(
                    .reminderSnoozed,
                    properties: ["snooze_option": option.analyticsValue]
                )
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
                clearDeleteUndo()
                Haptics.success()
                AppAnalytics.shared.track(
                    .reminderRestored,
                    properties: ["from_status": ReminderStatus.deleted.rawValue, "source": "undo_delete"]
                )
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

    private func refreshScheduledNotificationContentIfNeeded() {
        guard !didRefreshScheduledNotifications else {
            return
        }
        didRefreshScheduledNotifications = true

        Task {
            let status = await NotificationService.shared.authorizationStatus()
            guard status == .authorized || status == .provisional else {
                return
            }
            await ReminderStore(context: modelContext).refreshScheduledNotifications(for: reminders)
        }
    }

    private func showNotificationPreviewHintIfNeeded() async {
        guard !didShowNotificationPreviewHint else {
            return
        }

        let shouldSuggest = await NotificationService.shared.shouldSuggestEnablingNotificationPreviews()
        guard shouldSuggest else {
            notificationNoticeMessage = nil
            return
        }

        didShowNotificationPreviewHint = true
        notificationNoticeMessage = "系统隐藏了通知内容，到点可能只显示“1个通知”。打开通知预览后会显示具体任务名。"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func tint(for period: ReminderArchivePeriod) -> Color {
        switch period {
        case .overdue:
            return .orange
        case .today:
            return .green
        case .thisWeek:
            return .blue
        case .nextWeek:
            return .mint
        case .thisMonth:
            return .indigo
        case .nextMonth:
            return .cyan
        case .thisQuarter:
            return .purple
        case .thisHalfYear:
            return .teal
        case .thisYear:
            return .yellow
        case .twoYears:
            return .pink
        case .threeYears:
            return .brown
        case .fourYears:
            return .red
        case .fiveYears:
            return .orange
        case .beyondFiveYears:
            return .gray
        }
    }

    private func refreshCurrentDate() {
        currentDate = Date()
    }

    private func toggleSearch() {
        withAnimation(.snappy) {
            isSearchPresented.toggle()
            if isSearchPresented {
                isReminderSearchFocused = true
                AppAnalytics.shared.track(.searchUsed, properties: ["screen": "today"])
            } else {
                reminderSearchText = ""
                selectedTagFilter = nil
                isReminderSearchFocused = false
            }
        }
    }

    private func showDeleteUndo(_ reminder: Reminder, previousStatus: ReminderStatus) {
        let token = UUID()
        deleteUndoReminder = reminder
        deleteUndoStatus = previousStatus
        deleteUndoToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard deleteUndoToken == token else {
                return
            }
            clearDeleteUndo()
        }
    }

    private func clearDeleteUndo() {
        deleteUndoReminder = nil
        deleteUndoStatus = nil
        deleteUndoToken = nil
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

    private func analyticsProperties(for parsed: ParsedReminder, source: String) -> [String: String] {
        var properties: [String: String] = [
            "source": source,
            "tag": parsed.tag.rawValue,
            "has_repeat": "\((parsed.repeatRule?.type ?? .none) != .none)"
        ]

        if let datetime = parsed.datetime {
            properties["time_bucket"] = analyticsTimeBucket(for: datetime)
        }

        return properties
    }

    private func analyticsProperties(for reminder: Reminder, source: String) -> [String: String] {
        [
            "source": source,
            "tag": reminder.tag.rawValue,
            "has_repeat": "\(reminder.repeatRule.type != .none)",
            "time_bucket": analyticsTimeBucket(for: reminder.remindAt)
        ]
    }

    private func analyticsTimeBucket(for date: Date) -> String {
        switch ReminderArchivePeriod.period(for: date, now: currentDate, calendar: .current, includeOverdue: true) {
        case .overdue:
            return "overdue"
        case .today:
            return "today"
        case .thisWeek:
            return "this_week"
        case .nextWeek:
            return "next_week"
        case .thisMonth:
            return "this_month"
        case .nextMonth:
            return "next_month"
        case .thisQuarter:
            return "this_quarter"
        case .thisHalfYear:
            return "half_year"
        case .thisYear:
            return "one_year"
        case .twoYears:
            return "two_years"
        case .threeYears:
            return "three_years"
        case .fourYears:
            return "four_years"
        case .fiveYears:
            return "five_years"
        case .beyondFiveYears:
            return "after_five_years"
        }
    }
}

private struct ReminderArchiveSection: Identifiable {
    let period: ReminderArchivePeriod
    let reminders: [Reminder]

    var id: ReminderArchivePeriod { period }
}

private struct ReminderTagFilterOption: Identifiable {
    let tag: ReminderTag
    let count: Int

    var id: ReminderTag { tag }
}

#Preview {
    TodayView()
        .modelContainer(PreviewContainer.inMemory)
}
