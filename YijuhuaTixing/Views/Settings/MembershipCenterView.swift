import SwiftUI

struct MembershipCenterView: View {
    @Environment(\.openURL) private var openURL

    let subscriptionStore: SubscriptionStore
    let promptMessage: String?
    let source: String

    init(
        subscriptionStore: SubscriptionStore,
        promptMessage: String? = nil,
        source: String = "settings"
    ) {
        self.subscriptionStore = subscriptionStore
        self.promptMessage = promptMessage
        self.source = source
    }

    var body: some View {
        Form {
            statusSection
            benefitsSection
            plansSection
            restoreSection
            termsSection
        }
        .navigationTitle("会员中心")
        .task {
            await subscriptionStore.load(source: source)
        }
        .refreshable {
            await subscriptionStore.load(source: "manual_refresh")
        }
    }

    private var statusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("升级 Pro，让一句话提醒真正替你省时间")
                    .font(.headline)
                Text(subscriptionStore.entitlement.membershipStatus.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(subscriptionStore.hasProAccess ? .green : .secondary)
                if let promptMessage {
                    Text(promptMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                if let expiresAt = subscriptionStore.entitlement.expiresAt {
                    Text("有效期至 \(DateFormatterProvider.fullDateTimeFormatter.string(from: expiresAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var benefitsSection: some View {
        Section("Pro 权益") {
            benefitRow("不限提醒数量", systemImage: "infinity")
            benefitRow("语音输入", systemImage: "mic")
            benefitRow("Siri / 快捷指令创建提醒", systemImage: "sparkles")
            benefitRow("高级标签筛选", systemImage: "tag")
            benefitRow("历史误删恢复", systemImage: "arrow.uturn.backward")
        }
    }

    private var plansSection: some View {
        Section {
            if subscriptionStore.isLoadingProducts {
                ProgressView("正在加载会员信息...")
            }

            if let errorMessage = subscriptionStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            ForEach(subscriptionStore.planOptions) { option in
                Button {
                    Task {
                        await subscriptionStore.purchase(option.plan)
                    }
                } label: {
                    planRow(option)
                }
                .disabled(!option.isPurchasable || subscriptionStore.isPurchasing)
            }
        } header: {
            Text("套餐")
        } footer: {
            Text("首版计划提供 1 个月免费试用，试用资格、价格和周期以 App Store 展示为准。付款将通过 Apple ID 扣款；试用结束后订阅会自动续费，并在当前周期结束前 24 小时内扣费。如需取消，请在当前周期结束至少 24 小时前前往 Apple ID 的“订阅”关闭自动续费。")
        }
    }

    private var restoreSection: some View {
        Section {
            Button(subscriptionStore.isPurchasing ? "处理中..." : "恢复购买") {
                Task {
                    await subscriptionStore.restorePurchases()
                }
            }
            .disabled(subscriptionStore.isPurchasing)

            if let noticeMessage = subscriptionStore.noticeMessage {
                Text(noticeMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var termsSection: some View {
        Section {
            Button("用户协议") {
                open(termsURL)
            }
            Button("隐私政策") {
                open(privacyURL)
            }
            Button("会员服务协议") {
                open(membershipURL)
            }
            Button("联系支持") {
                open(supportURL)
            }
        } footer: {
            Text("购买或恢复购买前，请确认已阅读并同意相关协议。订阅扣费、取消订阅和退款由 Apple App Store 处理。")
        }
    }

    private func benefitRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
    }

    private func planRow(_ option: SubscriptionPlanOption) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(option.plan.displayName)
                        .font(.headline)

                    if let badgeText = option.plan.badgeText {
                        Text(badgeText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }

                Text(option.plan.monthlyHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(option.displayPrice)
                    .font(.headline.monospacedDigit())
                Text(option.plan.periodText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .opacity(option.isPurchasable ? 1 : 0.58)
        .padding(.vertical, 4)
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
}
