import SwiftUI

struct NotificationPermissionSheet: View {
    var onAllow: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("开启通知")
                    .font(.title2.weight(.semibold))
                Text("需要开启通知，才能到点提醒你。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("一句话提醒")
                    .font(.headline)
                Text("给客户发报价")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            PrimaryButton(title: "开启通知", action: onAllow)

            Button("稍后再说", action: onLater)
        }
        .padding(24)
        .presentationDetents([.height(420)])
    }
}
