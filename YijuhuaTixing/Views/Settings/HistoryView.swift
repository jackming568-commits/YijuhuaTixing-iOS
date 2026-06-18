import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Reminder.updatedAt, order: .reverse) private var reminders: [Reminder]
    @State private var selectedSegment: HistorySegment = .completed
    @State private var currentDate = Date()
    @State private var permanentDeleteTarget: Reminder?
    @State private var batchPermanentDeleteTargets: [Reminder] = []
    @State private var isSelectingRecords = false
    @State private var selectedRecordIds = Set<UUID>()
    @State private var errorMessage: String?
    @State private var historySearchText = ""
    @State private var historySpeechInput = SpeechInputService()
    @State private var subscriptionStore = SubscriptionStore()
    @State private var isMembershipCenterPresented = false
    @State private var membershipCenterMessage: String?
    @State private var membershipCenterSource = "feature_gate"

    var body: some View {
        VStack(spacing: 0) {
            Picker("历史类型", selection: $selectedSegment) {
                ForEach(HistorySegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)

            historySearchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List {
                switch selectedSegment {
                case .completed:
                    completedContent
                case .deleted:
                    deletedContent
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(2)
        }
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if hasSelectableHistoryItems {
                    Button(isSelectingRecords ? "完成" : "选择") {
                        if isSelectingRecords {
                            clearHistorySelection()
                        } else {
                            isSelectingRecords = true
                        }
                    }
                }
            }
        }
        .confirmationDialog("完全删除这条记录？", isPresented: isPermanentDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("完全删除", role: .destructive) {
                if let permanentDeleteTarget {
                    permanentlyDelete(permanentDeleteTarget)
                }
                permanentDeleteTarget = nil
            }
            Button("取消", role: .cancel) {
                permanentDeleteTarget = nil
            }
        } message: {
            Text("完全删除后会从系统数据和删除记录中移除，无法恢复。")
        }
        .confirmationDialog("完全删除 \(batchPermanentDeleteTargets.count) 条记录？", isPresented: isBatchPermanentDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("完全删除 \(batchPermanentDeleteTargets.count) 条", role: .destructive) {
                permanentlyDelete(batchPermanentDeleteTargets)
                batchPermanentDeleteTargets = []
            }
            Button("取消", role: .cancel) {
                batchPermanentDeleteTargets = []
            }
        } message: {
            Text("这些记录会从系统数据和删除记录中移除，无法恢复。")
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
        .alert("操作失败", isPresented: isErrorPresented) {
            Button("知道了") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            refreshCurrentDate()
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
        .onChange(of: selectedSegment) { _, _ in
            clearHistorySelection()
        }
        .onChange(of: historySpeechInput.transcript) { _, transcript in
            let normalizedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedTranscript.isEmpty {
                historySearchText = normalizedTranscript
            }
        }
        .onChange(of: visibleHistoryIds) { _, ids in
            selectedRecordIds.formIntersection(Set(ids))
            if ids.isEmpty {
                clearHistorySelection()
            }
        }
    }

    private var historySearchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索历史关键词", text: $historySearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        historySearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("清空历史搜索")
                }

                Button {
                    toggleHistoryVoiceInput()
                } label: {
                    Image(systemName: historySpeechInput.isListening ? "stop.circle.fill" : "mic.fill")
                        .font(historySpeechInput.isListening ? .title3 : .body)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(historySpeechInput.isListening ? .red : .secondary)
                .accessibilityLabel(historySpeechInput.isListening ? "停止语音搜索" : "开始语音搜索")
            }
            .frame(minHeight: 44)

            if let message = historySpeechInput.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(historySpeechInput.isShowingError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, historySpeechInput.statusMessage == nil ? 0 : 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(historySpeechInput.isListening ? Color.red.opacity(0.35) : Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var completedContent: some View {
        if completedSections.isEmpty {
            emptyRow(
                title: isSearchingHistory ? "没有匹配的已完成任务" : "暂无已完成任务",
                subtitle: isSearchingHistory ? "换个关键词试试，可以搜任务内容、原始输入或日期。" : "完成后的任务会保留在这里，方便回想。"
            )
        } else {
            if isSelectingRecords {
                historyBatchActionRow
            }

            ForEach(completedSections) { section in
                Section {
                    ForEach(section.items) { item in
                        completedHistoryRow(for: item, period: section.period)
                    }
                } header: {
                    PeriodSectionHeader(
                        title: section.period.title,
                        subtitle: section.period.rangeHint,
                        count: section.items.count,
                        systemImage: section.period.systemImage,
                        tint: tint(for: section.period)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var deletedContent: some View {
        if deletedItems.isEmpty {
            emptyRow(
                title: isSearchingHistory ? "没有匹配的已删除任务" : "暂无已删除任务",
                subtitle: isSearchingHistory ? "换个关键词试试，可以搜任务内容、原始输入或日期。" : "删除后且未撤销的任务会出现在这里。"
            )
        } else {
            if isSelectingRecords {
                historyBatchActionRow
            }

            ForEach(deletedItems) { item in
                deletedHistoryRow(for: item)
            }
        }
    }

    private var historyBatchActionRow: some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedRecordIds.count) 条")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Button(allHistoryItemsSelected ? "取消全选" : "全选") {
                toggleAllHistorySelection()
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                prepareBatchPermanentDelete()
            } label: {
                Label("完全删除", systemImage: "trash.slash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedRecordIds.isEmpty)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func completedHistoryRow(for item: CompletedHistoryItem, period: ReminderHistoryPeriod) -> some View {
        let periodTint = tint(for: period)

        if isSelectingRecords {
            historyRow(
                reminder: item.reminder,
                actionDate: item.completedAt,
                actionTitle: "完成于",
                systemImage: "checkmark.circle.fill",
                tint: periodTint,
                isSelected: selectedRecordIds.contains(item.id),
                permanentDeleteAction: nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                toggleHistorySelection(item.id)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(selectedRecordIds.contains(item.id) ? "已选择" : "未选择")
        } else {
            historyRow(
                reminder: item.reminder,
                actionDate: item.completedAt,
                actionTitle: "完成于",
                systemImage: "checkmark.circle.fill",
                tint: periodTint,
                permanentDeleteAction: {
                    permanentDeleteTarget = item.reminder
                }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    permanentDeleteTarget = item.reminder
                } label: {
                    Label("完全删除", systemImage: "trash.slash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    restore(item.reminder)
                } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward.circle")
                }
                .tint(.green)
            }
        }
    }

    @ViewBuilder
    private func deletedHistoryRow(for item: DeletedHistoryItem) -> some View {
        if isSelectingRecords {
            historyRow(
                reminder: item.reminder,
                actionDate: item.deletedAt,
                actionTitle: "删除于",
                systemImage: "trash.fill",
                tint: .red,
                isSelected: selectedRecordIds.contains(item.id),
                permanentDeleteAction: nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                toggleHistorySelection(item.id)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(selectedRecordIds.contains(item.id) ? "已选择" : "未选择")
        } else {
            historyRow(
                reminder: item.reminder,
                actionDate: item.deletedAt,
                actionTitle: "删除于",
                systemImage: "trash.fill",
                tint: .red,
                permanentDeleteAction: {
                    permanentDeleteTarget = item.reminder
                }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    permanentDeleteTarget = item.reminder
                } label: {
                    Label("完全删除", systemImage: "trash.slash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    restore(item.reminder)
                } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward.circle")
                }
                .tint(.green)
            }
        }
    }

    private func emptyRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
    }

    private func historyRow(
        reminder: Reminder,
        actionDate: Date,
        actionTitle: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool? = nil,
        permanentDeleteAction: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if let isSelected {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.red : Color.secondary)
                    .frame(width: 30, height: 44)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.shortDayFormatter.string(from: actionDate))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(DateFormatterProvider.timeFormatter.string(from: actionDate))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(tint)
            }
            .frame(width: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ReminderTagChip(tag: reminder.tag)

                    Label("\(actionTitle) \(Self.dateTimeFormatter.string(from: actionDate))", systemImage: systemImage)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                .lineLimit(1)

                Text("提醒时间 \(Self.dateTimeFormatter.string(from: reminder.remindAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if shouldShowRawInputHint(for: reminder) {
                    Text(reminder.rawInput)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let permanentDeleteAction {
                Button(action: permanentDeleteAction) {
                    Image(systemName: "trash.slash")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("完全删除")
            }
        }
        .padding(.vertical, 12)
    }

    private var isPermanentDeleteConfirmationPresented: Binding<Bool> {
        Binding {
            permanentDeleteTarget != nil
        } set: { isPresented in
            if !isPresented {
                permanentDeleteTarget = nil
            }
        }
    }

    private var isBatchPermanentDeleteConfirmationPresented: Binding<Bool> {
        Binding {
            !batchPermanentDeleteTargets.isEmpty
        } set: { isPresented in
            if !isPresented {
                batchPermanentDeleteTargets = []
            }
        }
    }

    private var isErrorPresented: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private var completedSections: [CompletedHistorySection] {
        let items = reminders.compactMap { reminder -> CompletedHistoryItem? in
            guard
                reminder.isCompleted,
                let completedAt = reminder.completedAt,
                let period = ReminderHistoryPeriod.period(for: completedAt, now: currentDate, calendar: .current),
                ReminderKeywordMatcher.matches(reminder: reminder, keyword: historySearchText, actionDate: completedAt)
            else {
                return nil
            }
            return CompletedHistoryItem(period: period, reminder: reminder, completedAt: completedAt)
        }

        let grouped = Dictionary(grouping: items) { $0.period }
        return ReminderHistoryPeriod.sectionOrder.compactMap { period in
            guard let items = grouped[period], !items.isEmpty else {
                return nil
            }
            return CompletedHistorySection(
                period: period,
                items: items.sorted { $0.completedAt > $1.completedAt }
            )
        }
    }

    private var deletedItems: [DeletedHistoryItem] {
        reminders.compactMap { reminder -> DeletedHistoryItem? in
            let deletedAt = reminder.updatedAt
            guard
                reminder.isDeleted,
                ReminderHistoryPeriod.isWithinFiveYears(deletedAt, now: currentDate, calendar: .current),
                ReminderKeywordMatcher.matches(reminder: reminder, keyword: historySearchText, actionDate: deletedAt)
            else {
                return nil
            }
            return DeletedHistoryItem(reminder: reminder, deletedAt: deletedAt)
        }
        .sorted { $0.deletedAt > $1.deletedAt }
    }

    private var hasSelectableHistoryItems: Bool {
        !visibleHistoryIds.isEmpty
    }

    private var visibleHistoryIds: [UUID] {
        switch selectedSegment {
        case .completed:
            return completedSections.flatMap(\.items).map(\.id)
        case .deleted:
            return deletedItems.map(\.id)
        }
    }

    private var allHistoryItemsSelected: Bool {
        !visibleHistoryIds.isEmpty && selectedRecordIds.count == visibleHistoryIds.count
    }

    private var selectedHistoryReminders: [Reminder] {
        switch selectedSegment {
        case .completed:
            return completedSections
                .flatMap(\.items)
                .filter { selectedRecordIds.contains($0.id) }
                .map(\.reminder)
        case .deleted:
            return deletedItems
                .filter { selectedRecordIds.contains($0.id) }
                .map(\.reminder)
        }
    }

    private var isSearchingHistory: Bool {
        !historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func tint(for period: ReminderHistoryPeriod) -> Color {
        switch period {
        case .today:
            return .green
        case .thisWeek:
            return .blue
        case .thisMonth:
            return .indigo
        case .thisQuarter:
            return .purple
        case .thisHalfYear:
            return .teal
        case .thisYear:
            return .cyan
        case .twoYears:
            return .pink
        case .threeYears:
            return .brown
        case .fiveYears:
            return .red
        }
    }

    private func shouldShowRawInputHint(for reminder: Reminder) -> Bool {
        let rawInput = reminder.rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawInput.isEmpty, rawInput != reminder.title else {
            return false
        }
        return reminder.title.count <= 2 || reminder.parseConfidence < 0.8
    }

    private func refreshCurrentDate() {
        currentDate = Date()
    }

    private func toggleHistorySelection(_ id: UUID) {
        if selectedRecordIds.contains(id) {
            selectedRecordIds.remove(id)
        } else {
            selectedRecordIds.insert(id)
        }
    }

    private func toggleAllHistorySelection() {
        if allHistoryItemsSelected {
            selectedRecordIds.removeAll()
        } else {
            selectedRecordIds = Set(visibleHistoryIds)
        }
    }

    private func clearHistorySelection() {
        isSelectingRecords = false
        selectedRecordIds.removeAll()
        batchPermanentDeleteTargets = []
    }

    private func prepareBatchPermanentDelete() {
        batchPermanentDeleteTargets = selectedHistoryReminders
    }

    private func toggleHistoryVoiceInput() {
        Task {
            if historySpeechInput.isListening {
                await historySpeechInput.toggleListening()
                return
            }

            guard subscriptionStore.hasProAccess else {
                showProFeatureBlocked(.voiceInput, source: "history_search_voice")
                return
            }

            await historySpeechInput.toggleListening()
        }
    }

    private func permanentlyDelete(_ reminder: Reminder) {
        do {
            try ReminderStore(context: modelContext).permanentlyDelete(reminder)
            selectedRecordIds.remove(reminder.id)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }

    private func permanentlyDelete(_ reminders: [Reminder]) {
        do {
            try ReminderStore(context: modelContext).permanentlyDelete(reminders)
            clearHistorySelection()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }

    private func restore(_ reminder: Reminder) {
        guard subscriptionStore.hasProAccess else {
            showProFeatureBlocked(.historyRestore, source: "history_restore")
            return
        }

        let fromStatus = reminder.status
        Task {
            do {
                try await ReminderStore(context: modelContext).restore(reminder)
                selectedRecordIds.remove(reminder.id)
                Haptics.success()
                AppAnalytics.shared.track(
                    .reminderRestored,
                    properties: [
                        "from_status": fromStatus.rawValue,
                        "source": "history_restore",
                        "is_overdue": "\(reminder.remindAt < currentDate)"
                    ]
                )
            } catch {
                errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func showProFeatureBlocked(_ feature: ProFeature, source: String) {
        membershipCenterMessage = feature.blockedMessage
        membershipCenterSource = source
        AppAnalytics.shared.track(
            .proFeatureBlocked,
            properties: ["feature": feature.rawValue, "source": source]
        )
        Haptics.warning()
        isMembershipCenterPresented = true
    }

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

private enum HistorySegment: String, CaseIterable, Identifiable {
    case completed
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .completed:
            return "已完成"
        case .deleted:
            return "已删除"
        }
    }
}

private struct CompletedHistorySection: Identifiable {
    let period: ReminderHistoryPeriod
    let items: [CompletedHistoryItem]

    var id: ReminderHistoryPeriod { period }
}

private struct CompletedHistoryItem: Identifiable {
    let period: ReminderHistoryPeriod
    let reminder: Reminder
    let completedAt: Date

    var id: UUID { reminder.id }
}

private struct DeletedHistoryItem: Identifiable {
    let reminder: Reminder
    let deletedAt: Date

    var id: UUID { reminder.id }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(PreviewContainer.inMemory)
}
