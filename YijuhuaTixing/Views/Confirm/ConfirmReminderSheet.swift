import SwiftUI

struct ConfirmReminderSheet: View {
    @State private var viewModel: ConfirmReminderViewModel
    @State private var showTimeEditor: Bool
    @FocusState private var isTitleFocused: Bool
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
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        summaryCard

                        titleSection

                        timeSection

                        repeatSection

                        suggestionsSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                }

                Divider()

                bottomActions
            }
            .navigationTitle("确认提醒")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTitleFocused = viewModel.titleIsMissing
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
                withAnimation(.snappy) {
                    showTimeEditor.toggle()
                }
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
                DatePicker(
                    "选择时间",
                    selection: Binding(
                        get: { viewModel.remindAt },
                        set: { viewModel.updateRemindAt($0) }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.55), lineWidth: 1)
        )
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
                                showTimeEditor = false
                            } else {
                                showTimeEditor = true
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
