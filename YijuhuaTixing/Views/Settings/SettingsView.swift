import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var debugNotificationStatus: String?
    @State private var isRequestingAuthorization = false
#if DEBUG
    @State private var isSchedulingDebugNotification = false
#endif
    @AppStorage("morningDefaultHour") private var morningDefaultHour = 9
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = 20

    var body: some View {
        NavigationStack {
            Form {
                Section("通知") {
                    HStack {
                        Text("通知权限")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }

                    switch authorizationStatus {
                    case .notDetermined:
                        Button(isRequestingAuthorization ? "正在开启..." : "开启通知") {
                            requestAuthorization()
                        }
                        .disabled(isRequestingAuthorization)
                    case .denied:
                        Button("前往系统设置") {
                            openSystemSettings()
                        }
                    case .authorized, .provisional, .ephemeral:
                        Button("刷新状态") {
                            refreshAuthorizationStatus()
                        }
                    @unknown default:
                        Button("刷新状态") {
                            refreshAuthorizationStatus()
                        }
                    }
                }

                Section("默认时间") {
                    Stepper("早上 \(morningDefaultHour):00", value: $morningDefaultHour, in: 5...11)
                    Stepper("晚上 \(eveningDefaultHour):00", value: $eveningDefaultHour, in: 18...23)
                }

#if DEBUG
                Section("开发测试") {
                    Button(isSchedulingDebugNotification ? "正在安排..." : "1分钟后测试通知") {
                        scheduleDebugNotification()
                    }
                    .disabled(isSchedulingDebugNotification)

                    if let debugNotificationStatus {
                        Text(debugNotificationStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
#endif

                Section("支持") {
                    ShareLink("反馈问题", item: feedbackTemplate)
                    NavigationLink("隐私说明") {
                        Text("请不要在反馈中提交密码、证件号、银行卡号等敏感信息。")
                            .padding()
                            .navigationTitle("隐私说明")
                    }
                }

                Section {
                    Text("一句话提醒 v0.1")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await refreshAuthorizationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshAuthorizationStatus()
                }
            }
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未请求"
        case .denied:
            return "已关闭"
        case .authorized, .provisional, .ephemeral:
            return "已开启"
        @unknown default:
            return "未知"
        }
    }

    private var statusColor: Color {
        authorizationStatus == .denied ? .orange : .secondary
    }

    private var feedbackTemplate: String {
        """
        一句话提醒反馈

        问题描述：


        复现步骤：
        1.
        2.
        3.

        期望结果：


        实际结果：


        环境信息：
        App：一句话提醒 v0.1
        通知权限：\(statusText)
        早上默认时间：\(morningDefaultHour):00
        晚上默认时间：\(eveningDefaultHour):00
        """
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func refreshAuthorizationStatus() {
        Task {
            await refreshAuthorizationStatus()
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await NotificationService.shared.authorizationStatus()
    }

    private func requestAuthorization() {
        Task {
            isRequestingAuthorization = true
            defer { isRequestingAuthorization = false }

            do {
                _ = try await NotificationService.shared.requestAuthorization()
                await refreshAuthorizationStatus()
            } catch {
                debugNotificationStatus = error.localizedDescription
            }
        }
    }

#if DEBUG
    private func scheduleDebugNotification() {
        Task {
            isSchedulingDebugNotification = true
            defer { isSchedulingDebugNotification = false }

            do {
                var status = await NotificationService.shared.authorizationStatus()
                if status == .notDetermined {
                    _ = try await NotificationService.shared.requestAuthorization()
                    status = await NotificationService.shared.authorizationStatus()
                }
                authorizationStatus = status

                guard status == .authorized || status == .provisional else {
                    debugNotificationStatus = "通知权限未开启。"
                    return
                }

                let remindAt = Date().addingTimeInterval(60)
                let parsed = ParsedReminder(
                    title: "测试通知",
                    datetime: remindAt,
                    repeatRule: nil,
                    confidence: 1,
                    needsUserConfirmation: false,
                    missingFields: [],
                    rawInput: "1分钟后提醒我测试通知",
                    parseSource: .localRules,
                    suggestions: []
                )

                _ = try await ReminderStore(context: modelContext).create(from: parsed)
                let time = DateFormatterProvider.timeFormatter.string(from: remindAt)
                debugNotificationStatus = "已安排 \(time) 的测试通知。"
            } catch {
                debugNotificationStatus = error.localizedDescription
            }
        }
    }
#endif
}
