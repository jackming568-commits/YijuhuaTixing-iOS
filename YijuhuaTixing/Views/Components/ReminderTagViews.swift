import SwiftUI

struct ReminderTagChip: View {
    var tag: ReminderTag
    var isSelected = false
    var showsIcon = true
    var count: Int?

    var body: some View {
        HStack(spacing: 4) {
            if showsIcon {
                Image(systemName: tag.systemImage)
                    .font(.caption2.weight(.semibold))
            }

            Text(tag.displayName)
                .font(.caption2.weight(.semibold))

            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color(uiColor: .systemBackground).opacity(0.72), in: Capsule())
            }
        }
        .foregroundStyle(isSelected ? .white : tag.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isSelected ? tag.tint : tag.tint.opacity(0.12), in: Capsule())
    }
}

struct ReminderTagPicker: View {
    @Binding var selection: ReminderTag

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(ReminderTag.allCases) { tag in
                Button {
                    selection = tag
                    Haptics.lightTap()
                } label: {
                    ReminderTagChip(tag: tag, isSelected: selection == tag)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("标签：\(tag.displayName)")
            }
        }
    }
}

extension ReminderTag {
    var systemImage: String {
        switch self {
        case .businessVisit:
            return "person.2"
        case .meetingCommunication:
            return "bubble.left.and.bubble.right"
        case .businessTrip:
            return "airplane"
        case .waitingConfirmation:
            return "questionmark.bubble"
        case .dailyLife:
            return "house"
        case .leisure:
            return "gamecontroller"
        case .health:
            return "heart"
        case .learning:
            return "book"
        case .other:
            return "tag"
        }
    }

    var tint: Color {
        switch self {
        case .businessVisit:
            return .blue
        case .meetingCommunication:
            return .indigo
        case .businessTrip:
            return .teal
        case .waitingConfirmation:
            return .orange
        case .dailyLife:
            return .green
        case .leisure:
            return .purple
        case .health:
            return .red
        case .learning:
            return .cyan
        case .other:
            return .gray
        }
    }
}
