import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var reminder: Reminder
    @State private var viewModel: TaskDetailViewModel
    @State private var showDeleteConfirmation = false
    @State private var showSnoozeSheet = false
    @AppStorage("morningDefaultHour") private var morningDefaultHour = ParserSettings.default.morningDefaultHour
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = ParserSettings.default.eveningDefaultHour

    init(reminder: Reminder) {
        self.reminder = reminder
        _viewModel = State(initialValue: TaskDetailViewModel(reminder: reminder))
    }

    var body: some View {
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

            Section("提醒时间") {
                HStack {
                    Label(timeStatusLabel, systemImage: timeStatusIcon)
                        .font(.subheadline)
                        .foregroundStyle(timeStatusColor)
                    Spacer()
                }

                DatePicker("时间", selection: $viewModel.remindAt, displayedComponents: [.date, .hourAndMinute])
            }

            Section("重复") {
                RepeatRulePicker(repeatRule: $viewModel.repeatRule)
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
        .navigationTitle("提醒详情")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    save()
                }
                .disabled(!viewModel.canSave)
            }
        }
        .alert("保存失败", isPresented: isErrorPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("删除这个提醒？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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
        guard viewModel.canSave else {
            viewModel.errorMessage = viewModel.validationMessage
            return
        }

        Task {
            do {
                try await ReminderStore(context: modelContext).update(
                    reminder,
                    title: viewModel.trimmedTitle,
                    remindAt: viewModel.remindAt,
                    repeatRule: viewModel.repeatRule
                )
                Haptics.success()
                dismiss()
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func complete() {
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
        Task {
            do {
                try await ReminderStore(context: modelContext).snooze(reminder, option: option, settings: parserSettings)
                viewModel.sync(from: reminder)
                Haptics.success()
            } catch {
                viewModel.errorMessage = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    private func delete() {
        do {
            try ReminderStore(context: modelContext).delete(reminder)
            Haptics.success()
            dismiss()
        } catch {
            viewModel.errorMessage = error.localizedDescription
            Haptics.warning()
        }
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

    private var isOverdue: Bool {
        reminder.status != .completed && viewModel.remindAt < Date()
    }

    private var isSnoozed: Bool {
        reminder.status == .snoozed
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
        settings.eveningDefaultHour = eveningDefaultHour
        return settings
    }
}
