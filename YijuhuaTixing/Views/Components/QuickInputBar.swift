import SwiftUI

struct QuickInputBar: View {
    @Binding var text: String
    var isParsing: Bool
    var onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("例如：明天上午10点提醒我给客户发报价", text: $text, axis: .vertical)
                .focused($isFocused)
                .lineLimit(1...4)
                .submitLabel(.done)
                .onSubmit(onSubmit)

            if isParsing {
                ProgressView()
            } else if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    isFocused = true
                } label: {
                    Image(systemName: "mic.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Button(action: onSubmit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(minHeight: 56)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
