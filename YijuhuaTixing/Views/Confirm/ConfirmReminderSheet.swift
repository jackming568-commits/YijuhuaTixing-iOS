import SwiftUI
import UIKit

struct ConfirmReminderSheet: View {
    private static let dateButtonFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans-CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    @Environment(\.openURL) private var openURL
    @State private var viewModel: ConfirmReminderViewModel
    @State private var showTimeEditor: Bool
    @State private var draftRemindAt: Date
    @State private var showCalendarPicker = false
    @State private var didConfirmAddress = false
    @State private var showMapOptions = false
    @State private var mapOptions: [MapNavigationOption] = []
    @State private var mapNavigationAlert: ConfirmMapNavigationAlert?
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isAddressFocused: Bool
    var onConfirm: (ParsedReminder) -> Void
    var onCancel: () -> Void

    init(
        parsedReminder: ParsedReminder,
        settings: ParserSettings = .default,
        onConfirm: @escaping (ParsedReminder) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let viewModel = ConfirmReminderViewModel(parsedReminder: parsedReminder, settings: settings)
        _viewModel = State(initialValue: viewModel)
        _showTimeEditor = State(initialValue: viewModel.shouldShowTimeEditorInitially)
        _draftRemindAt = State(initialValue: viewModel.remindAt)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                summaryCard

                                titleSection

                                tagSection

                                timeSection

                                repeatSection

                                addressSection

                                suggestionsSection
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 18)
                            .padding(.bottom, 18)
                        }
                        .onAppear {
                            if showTimeEditor {
                                scrollToTimeEditorActions(with: proxy)
                            }
                        }
                        .onChange(of: showTimeEditor) { _, isShowing in
                            guard isShowing else {
                                return
                            }
                            scrollToTimeEditorActions(with: proxy)
                        }
                    }

                    Divider()

                    bottomActions
                }

                if showCalendarPicker {
                    calendarPickerLayer
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                        .zIndex(10)
                }
            }
            .navigationTitle("确认提醒")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTitleFocused = viewModel.titleIsMissing
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
        }
        .presentationDetents([.large])
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            if let validationMessage = viewModel.validationMessage, !viewModel.canConfirm {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(
                title: viewModel.primaryButtonTitle,
                isLoading: viewModel.isCreating,
                isDisabled: !viewModel.canConfirm
            ) {
                onConfirm(viewModel.buildParsedReminder())
            }

            Button("取消", action: onCancel)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .safeAreaPadding(.bottom, 8)
        .background(.regularMaterial)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.timeSummary)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                Image(systemName: viewModel.titleIsMissing ? "exclamationmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(viewModel.titleIsMissing ? .orange : .green)

                Text(viewModel.titleIsMissing ? "还差提醒内容" : viewModel.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.titleIsMissing ? .secondary : .primary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("任务内容")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(viewModel.titlePlaceholder, text: $viewModel.title, axis: .vertical)
                .font(.title3.weight(.semibold))
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
                .focused($isTitleFocused)
                .submitLabel(.done)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleTimeEditor()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(viewModel.timeNeedsAttention ? .orange : .blue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("提醒时间")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(viewModel.timeSummary)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    Image(systemName: showTimeEditor ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showTimeEditor {
                VStack(alignment: .leading, spacing: 10) {
                    dateSelectorRow

                    HStack {
                        Spacer(minLength: 0)

                        HitLimitedWheelTimePicker(
                            selection: $draftRemindAt,
                            isEnabled: !showCalendarPicker,
                            width: 240
                        )
                        .zIndex(0)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.blue)
                        Text("当前选择：\(DateFormatterProvider.fullDateTimeFormatter.string(from: draftRemindAt))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
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
                            Label("确认时间", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .id(ScrollTarget.timeEditorActions)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.55), lineWidth: 1)
        )
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
        .padding(.bottom, 4)
        .zIndex(3)
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

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ReminderTagPicker(selection: $viewModel.tag)
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("重复")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            RepeatRulePicker(repeatRule: $viewModel.repeatRule)
                .pickerStyle(.menu)
        }
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            addressSectionHeader

            TextField("填写地址（可选）", text: $viewModel.addressText, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
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
                    Label(didConfirmAddress ? "已确认地址" : "确认地址", systemImage: didConfirmAddress ? "checkmark.circle" : "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(didConfirmAddress ? .green : .blue)

                Button {
                    prepareMapNavigation()
                } label: {
                    Label("打开地图导航", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Text(didConfirmAddress ? "地址会随这条提醒一起保存。" : "确认后再点底部确认提醒。")
                    .font(.footnote)
                    .foregroundStyle(didConfirmAddress ? .green : .secondary)
            }
        }
    }

    private var addressSectionHeader: some View {
        Text("请输入目标地址（用于打开地图导航）：")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.blue)
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if !viewModel.original.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("快捷选择")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 10) {
                    ForEach(viewModel.original.suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            if viewModel.applySuggestion(suggestion) {
                                draftRemindAt = viewModel.remindAt
                                showCalendarPicker = false
                                showTimeEditor = false
                            } else {
                                draftRemindAt = viewModel.remindAt
                                showCalendarPicker = false
                                showTimeEditor = true
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func toggleTimeEditor() {
        withAnimation(.snappy) {
            if showTimeEditor {
                showCalendarPicker = false
                showTimeEditor = false
            } else {
                draftRemindAt = viewModel.remindAt
                showTimeEditor = true
            }
        }
    }

    private func confirmDraftTime() {
        showCalendarPicker = false
        viewModel.updateRemindAt(draftRemindAt)
        Haptics.lightTap()
        withAnimation(.snappy) {
            showTimeEditor = false
        }
    }

    private func cancelTimeEdit() {
        showCalendarPicker = false
        draftRemindAt = viewModel.remindAt
        withAnimation(.snappy) {
            showTimeEditor = false
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

    private func prepareMapNavigation() {
        showCalendarPicker = false
        confirmAddressEntry()
        let options = MapNavigationService.live.availableOptions(for: viewModel.trimmedAddressText)

        guard !options.isEmpty else {
            mapNavigationAlert = ConfirmMapNavigationAlert(
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

            mapNavigationAlert = ConfirmMapNavigationAlert(
                title: "未能打开该地图 App",
                message: "请换一个地图 App，或先去 App Store 下载地图。",
                showsDownloadAction: true
            )
            Haptics.warning()
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
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: draftRemindAt)

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
        min(max(size.height * 0.16, 116), 180)
    }

    private func scrollToTimeEditorActions(with proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.snappy) {
                proxy.scrollTo(ScrollTarget.timeEditorActions, anchor: .bottom)
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

    private enum ScrollTarget {
        static let timeEditorActions = "timeEditorActions"
    }
}

private struct ConfirmMapNavigationAlert {
    let title: String
    let message: String
    let showsDownloadAction: Bool
}

struct HitLimitedWheelTimePicker: UIViewRepresentable {
    @Binding var selection: Date
    var isEnabled: Bool
    var width: CGFloat
    var height: CGFloat = 128

    func makeUIView(context: Context) -> HitLimitedWheelTimePickerView {
        let view = HitLimitedWheelTimePickerView()
        view.datePicker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.datePickerValueChanged(_:)),
            for: .valueChanged
        )
        return view
    }

    func updateUIView(_ uiView: HitLimitedWheelTimePickerView, context: Context) {
        context.coordinator.parent = self
        uiView.isUserInteractionEnabled = isEnabled
        uiView.datePicker.isEnabled = isEnabled
        uiView.setNeedsLayout()

        if abs(uiView.datePicker.date.timeIntervalSince(selection)) > 0.5 {
            uiView.datePicker.date = selection
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ uiView: HitLimitedWheelTimePickerView, coordinator: Coordinator) {
        uiView.datePicker.removeTarget(
            coordinator,
            action: #selector(Coordinator.datePickerValueChanged(_:)),
            for: .valueChanged
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: HitLimitedWheelTimePickerView, context: Context) -> CGSize? {
        CGSize(width: width, height: height)
    }

    final class Coordinator: NSObject {
        var parent: HitLimitedWheelTimePicker

        init(parent: HitLimitedWheelTimePicker) {
            self.parent = parent
        }

        @objc func datePickerValueChanged(_ sender: UIDatePicker) {
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: sender.date)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: parent.selection)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute

            if let mergedDate = calendar.date(from: dateComponents) {
                parent.selection = mergedDate
            }
        }
    }
}

final class HitLimitedWheelTimePickerView: UIView {
    let datePicker = UIDatePicker()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        datePicker.datePickerMode = .time
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minuteInterval = 1
        datePicker.locale = Locale(identifier: "en_GB")
        datePicker.semanticContentAttribute = .forceLeftToRight
        addSubview(datePicker)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pickerHeight = max(datePicker.intrinsicContentSize.height, bounds.height)
        datePicker.bounds = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: pickerHeight))
        datePicker.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        isUserInteractionEnabled && bounds.contains(point)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard bounds.contains(point) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
