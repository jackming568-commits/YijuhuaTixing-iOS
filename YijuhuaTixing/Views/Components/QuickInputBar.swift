import SwiftUI

struct QuickInputBar: View {
    @Binding var text: String
    var isParsing: Bool
    var isListening: Bool = false
    var voiceMessage: String?
    var isVoiceMessageError: Bool = false
    var onVoiceTap: () -> Void = {}
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...4)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)

                if isParsing {
                    ProgressView()
                } else if isListening {
                    Button(action: onVoiceTap) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .accessibilityLabel("停止语音输入")
                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: onVoiceTap) {
                        Image(systemName: "mic.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("开始语音输入")
                } else {
                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let voiceMessage {
                Text(voiceMessage)
                    .font(.caption)
                    .foregroundStyle(isVoiceMessageError ? .red : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, voiceMessage == nil ? 0 : 8)
        .frame(minHeight: 56)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholder: String {
        isListening ? "正在听..." : "例如：明天上午10点提醒我给客户发报价"
    }

    private var borderColor: Color {
        if isListening {
            return .red.opacity(0.45)
        }

        if isFocused {
            return .accentColor
        }

        return .secondary.opacity(0.18)
    }
}
