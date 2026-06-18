import SwiftUI

struct PeriodSectionHeader: View {
    let title: String
    let subtitle: String
    let count: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(uiColor: .systemBackground).opacity(0.82), in: Capsule())
        }
        .foregroundStyle(tint)
        .textCase(nil)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.42), lineWidth: 1)
        )
        .padding(.top, 10)
        .padding(.bottom, 2)
        .accessibilityLabel("\(title)，\(subtitle)，\(count) 个提醒")
    }
}
