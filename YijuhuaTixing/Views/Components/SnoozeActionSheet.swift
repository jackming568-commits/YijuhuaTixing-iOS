import SwiftUI

struct SnoozeActionSheet: View {
    var onSelect: (SnoozeOption) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                snoozeButton(
                    title: "10分钟后",
                    subtitle: "马上处理，但先缓一缓",
                    systemImage: "timer",
                    option: .minutes(10)
                )

                snoozeButton(
                    title: "30分钟后",
                    subtitle: "适合路上、会议后再提醒",
                    systemImage: "clock",
                    option: .minutes(30)
                )

                snoozeButton(
                    title: "1小时后",
                    subtitle: "先放到今天稍后",
                    systemImage: "clock.arrow.circlepath",
                    option: .minutes(60)
                )

                snoozeButton(
                    title: "明天早上",
                    subtitle: "今天先不管，明早再出现",
                    systemImage: "sunrise",
                    option: .tomorrowMorning
                )

                Button("取消", role: .cancel, action: onCancel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .navigationTitle("稍后提醒")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(320)])
    }

    private func snoozeButton(title: String, subtitle: String, systemImage: String, option: SnoozeOption) -> some View {
        Button {
            onSelect(option)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
