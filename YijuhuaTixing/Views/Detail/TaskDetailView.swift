import SwiftUI

struct TaskDetailView: View {
    private static let dateButtonFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var reminder: Reminder
    @State private var viewModel: TaskDetailViewModel
    @State private var draftRemindAt: Date
    @State private var showDeleteConfirmation = false
    @State private var showSnoozeSheet = false
    @State private var didAutoFocusTimeEditor = false
    @State private var didConfirmDraftTime = false
    @State private var confirmationFeedbackID = 0
    @State private var showCalendarPicker = false
    @State private var showMapOptions = false
    @State private var mapOptions: [MapNavigationOption] = []
    @State private var mapNavigationAlert: MapNavigationAlert?
    @State private var didConfirmAddress = false
    @State private var isSaving = false
    @State private var didSaveSuccessfully = false
    @FocusState private var isAddressFocused: Bool
    @AppStorage("morningDefaultHour") private var morningDefaultHour = ParserSettings.default
        .morningDefaultHour
    @AppStorage("morningDefaultMinute") private var morningDefaultMinute = ParserSettings.default
        .morningDefaultMinute
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = ParserSettings.default
        .eveningDefaultHour
    @AppStorage("eveningDefaultMinute") private var eveningDefaultMinute = ParserSettings.default
        .eveningDefaultMinute

    init(reminder: Reminder) {
        self.reminder = reminder
        _viewModel = State(initialValue: TaskDetailViewModel(reminder: reminder))
        _draftRemindAt = State(initialValue: reminder.remindAt)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { scrollProxy in
                Form {
                    Section("任务") {
                        TextField("标题", text: $viewModel.title, axis: .vertical)
                            .lineLimit(1...4)

                        if let validationMessage = viewModel.validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("标签") {
                        ReminderTagPicker(selection: $viewModel.tag)
                    }

                    Section("提醒时间") {
                        HStack {
                            Label(timeStatusLabel, systemImage: timeStatusIcon)
                                .font(.subheadline)
                                .foregroundStyle(timeStatusColor)
                            Spacer()
                        }

                        dateSelectorRow

                        HStack {
                            Spacer(minLength: 0)

                            HitLimitedWheelTimePicker(
                                selection: $draftRemindAt,
                                isEnabled: !showCalendarPicker,
                                width: 240
                            )

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                            Text(
                                "当前选择：\(DateFormatterProvider.fullDateTimeFormatter.string(from: draftRemindAt))"
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        HStack(spacing: 10) {
                            Button("取消") {
                                cancelTimeEdit()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                            Button {
                                confirmDraftTime()
                            } label: {
                                Label(
                                    didConfirmDraftTime ? "已确认" : "确认时间",
                                    systemImage: didConfirmDraftTime
                                        ? "checkmark.circle" : "checkmark.circle.fill"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(didConfirmDraftTime ? .green : .blue)
                            .scaleEffect(didConfirmDraftTime ? 0.98 : 1)
                            .frame(maxWidth: .infinity)
                            .disabled(!canConfirmDraftTime)
                        }
                        .controlSize(.large)
                        .animation(
                            .spring(response: 0.22, dampingFraction: 0.72),
                            value: didConfirmDraftTime
                        )
                        .id(DetailScrollTarget.timeEditorActions)

                        HStack(spacing: 6) {
                            Image(
                                systemName: didConfirmDraftTime
                                    ? "checkmark.circle.fill" : "info.circle")
                            Text(
                                "已确认：\(DateFormatterProvider.fullDateTimeFormatter.string(from: viewModel.remindAt))，\(didConfirmDraftTime ? "现在可以点右上角保存。" : "确认后点右上角保存。")"
                            )
                        }
                        .font(.footnote)
                        .foregroundStyle(didConfirmDraftTime ? .green : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: didConfirmDraftTime)
                    }

                    Section("重复") {
                        RepeatRulePicker(repeatRule: $viewModel.repeatRule)
                    }

                    Section {
                        TextField("填写地址（可选）", text: $viewModel.addressText, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($isAddressFocused)
                            .submitLabel(.done)
                            .onSubmit(confirmAddressEntry)
                            .onChange(of: viewModel.addressText) { _, _ in
                                didConfirmAddress = false
                            }

                        if viewModel.hasAddress {
                            Button {
                                confirmAddressEntry()
                            } label: {
                                Label(
                                    didConfirmAddress ? "已确认地址" : "确认地址",
                                    systemImage: didConfirmAddress ? "checkmark.circle" : "checkmark.circle.fill"
                                )
                            }
                            .tint(didConfirmAddress ? .green : .blue)

                            Button {
                                prepareMapNavigation()
                            } label: {
                                Label("打开地图导航", systemImage: "map")
                            }

                            Text(didConfirmAddress ? "已确认地址，点右上角保存。" : "确认地址后再点右上角保存。")
                                .font(.footnote)
                                .foregroundStyle(didConfirmAddress ? .green : .secondary)
                        }
                    } header: {
                        addressSectionHeader
                    }

                    Section("原始输入") {
                        Text(reminder.rawInput)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button {
                            complete()
                        } label: {
                            Label("完成提醒", systemImage: "checkmark.circle")
                        }

                        Button {
                            showSnoozeSheet = true
                        } label: {
                            Label("稍后提醒", systemImage: "clock.arrow.circlepath")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("删除提醒", systemImage: "trash")
                        }
                    }
                }
                .listSectionSpacing(.compact)
                .onAppear {
                    focusTimeEditorIfNeeded(scrollProxy)
                }
                .onChange(of: draftRemindAt) { _, _ in
                    resetTimeConfirmationFeedback()
                }
            }

            if showCalendarPicker {
                calendarPickerLayer
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                    .zIndex(10)
            }

            if didSaveSuccessfully {
                saveSuccessBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .navigationTitle("提醒详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    saveButtonLabel
                }
                .buttonStyle(.plain)
                .disabled(!canTapSave)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: viewModel.canSave)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isSaving)
                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: didSaveSuccessfully)
            }
        }
        .alert("保存失败", isPresented: isErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(mapNavigationAlert?.title ?? "", isPresented: isMapAlertPresented) {
            if mapNavigationAlert?.showsDownloadAction == true {
                Button("去 App Store 下载地图") {
                    openURL(MapNavigationService.appStoreSearchURL)
                }
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(mapNavigationAlert?.message ?? "")
        }
        .confirmationDialog("选择地图 App", isPresented: $showMapOptions, titleVisibility: .visible) {
            ForEach(mapOptions) { option in
                Button(option.displayName) {
                    openMap(option)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(viewModel.trimmedAddressText)
        }
        .confirmationDialog(
            "删除这个提醒？", isPresented: $showDeleteConfirmation, titleVisibility: .visible
        ) {
            Button("删除提醒", role: .destructive) {
                delete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会再收到这条提醒。")
        }
        .sheet(isPresented: $showSnoozeSheet) {
            SnoozeActionSheet { option in
                snooze(option)
                showSnoozeSheet = false
            } onCancel: {
                showSnoozeSheet = false
            }
        }
    }

    private func save() {
        guard !isSaving else {
            return
        }

        showCalendarPicker = false

        guard viewModel.canSave else {
            viewModel.errorMessage = viewModel.validationMessage
            return
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
            isSaving = true
            didSaveSuccessfully = false
        }

        Task {
            do {
                try await ReminderStore(context: modelContext).update(
                    reminder,
                    title: viewModel.trimmedTitle,
                    remindAt: viewModel.remindAt,
                    repeatRule: viewModel.repeatRule,
                    tag: viewModel.tag,
                    addressText: viewModel.normalizedAddressText
                )
                Haptics.success()
                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    isSaving = false
                    didSaveSuccessfully = true
                }
                try? await Task.sleep(nanoseconds: 520_000_000)
                dismiss()
            } catch {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    isSaving = false
                    didSaveSuccessfully = false
                }
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func confirmDraftTime() {
        guard canConfirmDraftTime else {
            Haptics.warning()
            return
        }

        showCalendarPicker = false
        viewModel.remindAt = draftRemindAt
        Haptics.success()

        confirmationFeedbackID += 1
        let currentFeedbackID = confirmationFeedbackID

        withAnimation(.easeInOut(duration: 0.18)) {
            didConfirmDraftTime = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard confirmationFeedbackID == currentFeedbackID else {
                return
            }

            resetTimeConfirmationFeedback()
        }
    }

    private func cancelTimeEdit() {
        showCalendarPicker = false
        draftRemindAt = viewModel.remindAt
        resetTimeConfirmationFeedback()
        Haptics.lightTap()
    }

    private func focusTimeEditorIfNeeded(_ scrollProxy: ScrollViewProxy) {
        guard isOverdue, !didAutoFocusTimeEditor else {
            return
        }

        didAutoFocusTimeEditor = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                scrollProxy.scrollTo(DetailScrollTarget.timeEditorActions, anchor: .bottom)
            }
        }
    }

    private func resetTimeConfirmationFeedback() {
        withAnimation(.easeInOut(duration: 0.18)) {
            didConfirmDraftTime = false
        }
    }

    private func complete() {
        showCalendarPicker = false

        Task {
            do {
                try await ReminderStore(context: modelContext).complete(reminder)
                Haptics.success()
                dismiss()
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func snooze(_ option: SnoozeOption) {
        showCalendarPicker = false

        Task {
            do {
                try await ReminderStore(context: modelContext).snooze(
                    reminder, option: option, settings: parserSettings)
                viewModel.sync(from: reminder)
                draftRemindAt = viewModel.remindAt
                Haptics.success()
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func delete() {
        showCalendarPicker = false

        do {
            try ReminderStore(context: modelContext).delete(reminder)
            Haptics.success()
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            Haptics.warning()
        }
    }

    private func prepareMapNavigation() {
        showCalendarPicker = false
        let options = MapNavigationService.live.availableOptions(for: viewModel.trimmedAddressText)

        guard !options.isEmpty else {
            mapNavigationAlert = MapNavigationAlert(
                title: "未检测到可用地图 App",
                message: "请先下载地图 App，再打开地址导航。",
                showsDownloadAction: true
            )
            Haptics.warning()
            return
        }

        mapOptions = options
        showMapOptions = true
        Haptics.lightTap()
    }

    private func openMap(_ option: MapNavigationOption) {
        openURL(option.url) { accepted in
            guard !accepted else {
                return
            }

            mapNavigationAlert = MapNavigationAlert(
                title: "未能打开该地图 App",
                message: "请换一个地图 App，或先去 App Store 下载地图。",
                showsDownloadAction: true
            )
            Haptics.warning()
        }
    }

    private func confirmAddressEntry() {
        guard let addressText = viewModel.normalizedAddressText else {
            viewModel.addressText = ""
            didConfirmAddress = false
            isAddressFocused = false
            return
        }

        viewModel.addressText = addressText
        didConfirmAddress = true
        isAddressFocused = false
        Haptics.lightTap()
    }

    private var addressSectionHeader: some View {
        Text("请输入目标地址（用于打开地图导航）：")
            .foregroundStyle(.blue)
    }

    private var dateSelectorRow: some View {
        HStack(spacing: 12) {
            Label("日期", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                toggleCalendarPicker()
            } label: {
                HStack(spacing: 6) {
                    Text(Self.dateButtonFormatter.string(from: draftRemindAt))
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: showCalendarPicker ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(showCalendarPicker ? .white : .blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(showCalendarPicker ? Color.blue : Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .contentShape(Capsule(style: .continuous))
        }
    }

    private var calendarPickerLayer: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideCalendarPicker()
                    }

                VStack(spacing: 8) {
                    DatePicker(
                        "选择日期",
                        selection: calendarDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                    Divider()

                    Button {
                        hideCalendarPicker()
                    } label: {
                        Text("完成")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(14)
                .frame(width: min(proxy.size.width - 48, 340))
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 12)
                .padding(.top, calendarTopPadding(for: proxy.size))
            }
        }
    }

    private func toggleCalendarPicker() {
        withAnimation(.snappy) {
            showCalendarPicker.toggle()
        }
        Haptics.lightTap()
    }

    private func hideCalendarPicker() {
        withAnimation(.snappy) {
            showCalendarPicker = false
        }
    }

    private var calendarDateBinding: Binding<Date> {
        Binding {
            draftRemindAt
        } set: { newDate in
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
            let timeComponents = calendar.dateComponents(
                [.hour, .minute, .second], from: draftRemindAt)

            var mergedComponents = DateComponents()
            mergedComponents.year = dateComponents.year
            mergedComponents.month = dateComponents.month
            mergedComponents.day = dateComponents.day
            mergedComponents.hour = timeComponents.hour
            mergedComponents.minute = timeComponents.minute
            mergedComponents.second = timeComponents.second

            if let mergedDate = calendar.date(from: mergedComponents) {
                draftRemindAt = mergedDate
            } else {
                draftRemindAt = newDate
            }
        }
    }

    private func calendarTopPadding(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.14, 96), 150)
    }

    private var saveButtonLabel: some View {
        HStack(spacing: 6) {
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: didSaveSuccessfully ? "checkmark.circle.fill" : "checkmark")
                    .font(.subheadline.weight(.bold))
            }

            Text(saveButtonTitle)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(saveButtonForegroundColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(saveButtonBackgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(saveButtonBorderColor, lineWidth: viewModel.canSave ? 0 : 1)
        )
        .scaleEffect(isSaving || didSaveSuccessfully ? 0.96 : 1)
        .contentShape(Capsule(style: .continuous))
        .accessibilityLabel(saveButtonTitle)
    }

    private var saveSuccessBanner: some View {
        Label("已保存", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
            )
            .padding(.top, 8)
    }

    private var saveButtonTitle: String {
        if isSaving {
            return "保存中"
        }
        if didSaveSuccessfully {
            return "已保存"
        }
        return "保存"
    }

    private var canTapSave: Bool {
        viewModel.canSave && !isSaving && !didSaveSuccessfully
    }

    private var saveButtonForegroundColor: Color {
        viewModel.canSave || isSaving || didSaveSuccessfully ? .white : .secondary
    }

    private var saveButtonBackgroundColor: Color {
        if didSaveSuccessfully {
            return .green
        }
        if isSaving || viewModel.canSave {
            return .blue
        }
        return Color(.tertiarySystemFill)
    }

    private var saveButtonBorderColor: Color {
        viewModel.canSave ? .clear : Color(.separator).opacity(0.7)
    }

    private var isErrorPresented: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    }

    private var isMapAlertPresented: Binding<Bool> {
        Binding {
            mapNavigationAlert != nil
        } set: { isPresented in
            if !isPresented {
                mapNavigationAlert = nil
            }
        }
    }

    private var isOverdue: Bool {
        reminder.status != .completed && viewModel.remindAt < Date()
    }

    private var isSnoozed: Bool {
        reminder.status == .snoozed
    }

    private var canConfirmDraftTime: Bool {
        draftRemindAt > Date()
    }

    private var timeStatusLabel: String {
        if isOverdue {
            return DateFormatterProvider.overdueLabel(for: viewModel.remindAt)
        }
        if isSnoozed {
            return DateFormatterProvider.snoozedLabel(for: viewModel.remindAt)
        }
        return DateFormatterProvider.relativeDayLabel(for: viewModel.remindAt)
    }

    private var timeStatusIcon: String {
        if isOverdue {
            return "exclamationmark.circle"
        }
        if isSnoozed {
            return "clock.arrow.circlepath"
        }
        return "clock"
    }

    private var timeStatusColor: Color {
        if isOverdue {
            return .orange
        }
        if isSnoozed {
            return .blue
        }
        return .secondary
    }

    private var parserSettings: ParserSettings {
        var settings = ParserSettings.default
        settings.morningDefaultHour = morningDefaultHour
        settings.morningDefaultMinute = morningDefaultMinute
        settings.eveningDefaultHour = eveningDefaultHour
        settings.eveningDefaultMinute = eveningDefaultMinute
        return settings
    }
}

private enum DetailScrollTarget {
    static let timeEditorActions = "time-editor-actions"
}

private struct MapNavigationAlert {
    let title: String
    let message: String
    let showsDownloadAction: Bool
}
