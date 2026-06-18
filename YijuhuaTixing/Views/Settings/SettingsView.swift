import SwiftData
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var areNotificationPreviewsHidden = false
    @State private var debugNotificationStatus: String?
    @State private var deletedArchiveURL: URL?
    @State private var isRequestingAuthorization = false
    @State private var accountStore = AccountSessionStore()
    @State private var subscriptionStore = SubscriptionStore()
#if DEBUG
    @State private var isSchedulingDebugNotification = false
    @AppStorage("debug.forceProEntitlement.v2") private var isDebugProEnabled = false
#endif
    @AppStorage("morningDefaultHour") private var morningDefaultHour = ParserSettings.default.morningDefaultHour
    @AppStorage("morningDefaultMinute") private var morningDefaultMinute = ParserSettings.default.morningDefaultMinute
    @AppStorage("eveningDefaultHour") private var eveningDefaultHour = ParserSettings.default.eveningDefaultHour
    @AppStorage("eveningDefaultMinute") private var eveningDefaultMinute = ParserSettings.default.eveningDefaultMinute

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
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }

                    if shouldShowNotificationPreviewGuidance {
                        notificationPreviewGuidanceRow
                    }
                }

                Section("账号") {
                    NavigationLink {
                        PersonalCenterView(accountStore: accountStore)
                    } label: {
                        HStack {
                            Text("个人信息")
                            Spacer()
                            Text(accountStore.accountStatusText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("会员") {
                    NavigationLink {
                        MembershipCenterView(subscriptionStore: subscriptionStore)
                    } label: {
                        HStack {
                            Text("会员中心")
                            Spacer()
                            Text(subscriptionStore.entitlement.membershipStatus.displayName)
                                .foregroundStyle(subscriptionStore.hasProAccess ? .green : .secondary)
                        }
                    }
                }

                Section("默认时间") {
                    Stepper(
                        "早上 \(formattedDefaultTime(hour: morningDefaultHour, minute: morningDefaultMinute))",
                        value: morningDefaultTotalMinutes,
                        in: Self.morningDefaultMinuteRange,
                        step: 30
                    )
                    Stepper(
                        "晚上 \(formattedDefaultTime(hour: eveningDefaultHour, minute: eveningDefaultMinute))",
                        value: eveningDefaultTotalMinutes,
                        in: Self.eveningDefaultMinuteRange,
                        step: 30
                    )
                }

                Section("数据") {
                    NavigationLink("历史记录") {
                        HistoryView()
                    }

                    if let deletedArchiveURL {
                        ShareLink("导出删除记录", item: deletedArchiveURL)
                    } else {
                        Text("暂无删除记录")
                            .foregroundStyle(.secondary)
                    }
                }

#if DEBUG
                Section("开发测试") {
                    Toggle("临时 Pro 权益", isOn: $isDebugProEnabled)
                        .onChange(of: isDebugProEnabled) { _, isEnabled in
                            Task {
                                await subscriptionStore.refreshEntitlement()
                                debugNotificationStatus = isEnabled ? "已开启临时 Pro，可测试 Siri / 快捷指令。" : "已关闭临时 Pro。"
                            }
                        }

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
                    Button("联系支持") {
                        open(supportURL)
                    }
                    Button("隐私政策") {
                        open(privacyURL)
                    }
                    Button("用户协议") {
                        open(termsURL)
                    }
                    Button("会员服务协议") {
                        open(membershipURL)
                    }
                }

                Section {
                    Text("一句话提醒 v1.0")
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
                await refreshNotificationSettings()
                await subscriptionStore.refreshEntitlement()
                refreshDeletedArchiveURL()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refreshNotificationSettings()
                    refreshDeletedArchiveURL()
                }
            }
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未开启"
        case .denied:
            return "已关闭"
        case .authorized, .provisional, .ephemeral:
            return areNotificationPreviewsHidden ? "未开启" : "已开启"
        @unknown default:
            return "未知"
        }
    }

    private var statusColor: Color {
        if authorizationStatus == .denied || shouldShowNotificationPreviewGuidance {
            return .orange
        }
        return .secondary
    }

    private var shouldShowNotificationPreviewGuidance: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return areNotificationPreviewsHidden
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private var notificationPreviewGuidanceRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("通知预览")
                Spacer()
                Text("已隐藏")
                    .foregroundStyle(.orange)
            }

            Text("打开后，提醒横幅会显示具体任务名。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("打开通知预览") {
                openSystemSettings()
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4)
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
        App：一句话提醒 v1.0
        通知权限：\(statusText)
        早上默认时间：\(formattedDefaultTime(hour: morningDefaultHour, minute: morningDefaultMinute))
        晚上默认时间：\(formattedDefaultTime(hour: eveningDefaultHour, minute: eveningDefaultMinute))
        """
    }

    private static let morningDefaultMinuteRange = (5 * 60)...(11 * 60)
    private static let eveningDefaultMinuteRange = (18 * 60)...(23 * 60)

    private var morningDefaultTotalMinutes: Binding<Int> {
        Binding(
            get: { morningDefaultHour * 60 + morningDefaultMinute },
            set: { totalMinutes in
                let rounded = roundedDefaultMinutes(totalMinutes, in: Self.morningDefaultMinuteRange)
                morningDefaultHour = rounded / 60
                morningDefaultMinute = rounded % 60
            }
        )
    }

    private var eveningDefaultTotalMinutes: Binding<Int> {
        Binding(
            get: { eveningDefaultHour * 60 + eveningDefaultMinute },
            set: { totalMinutes in
                let rounded = roundedDefaultMinutes(totalMinutes, in: Self.eveningDefaultMinuteRange)
                eveningDefaultHour = rounded / 60
                eveningDefaultMinute = rounded % 60
            }
        )
    }

    private func formattedDefaultTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func roundedDefaultMinutes(_ totalMinutes: Int, in range: ClosedRange<Int>) -> Int {
        let clamped = min(max(totalMinutes, range.lowerBound), range.upperBound)
        return (clamped / 30) * 30
    }

    private var privacyURL: URL {
        URL(string: "https://yijuhuatixing.cn/privacy")!
    }

    private var termsURL: URL {
        URL(string: "https://yijuhuatixing.cn/terms")!
    }

    private var membershipURL: URL {
        URL(string: "https://yijuhuatixing.cn/membership")!
    }

    private var supportURL: URL {
        URL(string: "https://yijuhuatixing.cn/support")!
    }

    private func open(_ url: URL) {
        openURL(url)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func refreshNotificationSettings() {
        Task {
            await refreshNotificationSettings()
        }
    }

    private func refreshNotificationSettings() async {
        authorizationStatus = await NotificationService.shared.authorizationStatus()
        areNotificationPreviewsHidden = await NotificationService.shared.areNotificationPreviewsHidden()
    }

    private func refreshDeletedArchiveURL() {
        guard
            let rawURL = try? DeletedReminderArchive.shared.archiveURL(),
            FileManager.default.fileExists(atPath: rawURL.path),
            let groupedURL = try? DeletedReminderArchive.shared.groupedArchiveURL()
        else {
            deletedArchiveURL = nil
            return
        }
        deletedArchiveURL = groupedURL
    }

    private func requestAuthorization() {
        Task {
            isRequestingAuthorization = true
            defer { isRequestingAuthorization = false }

            do {
                _ = try await NotificationService.shared.requestAuthorization()
                await refreshNotificationSettings()
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
                areNotificationPreviewsHidden = await NotificationService.shared.areNotificationPreviewsHidden()

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
