import SwiftUI

struct PersonalCenterView: View {
    let accountStore: AccountSessionStore

    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var didRequestCode = false
    @State private var statusMessage: String?
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        Form {
            if let profile = accountStore.profile {
                profileSection(profile)
                accountActionSection
            } else {
                loginSection
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("个人信息")
        .alert("操作失败", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {
                accountStore.errorMessage = nil
            }
        } message: {
            Text(accountStore.errorMessage ?? "")
        }
        .confirmationDialog("注销账号？", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("确认注销", role: .destructive) {
                Task {
                    if await accountStore.deleteAccount() {
                        statusMessage = "账号已注销，本机提醒数据已保留。"
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("注销后会清理账号缓存和会员缓存，本机提醒数据默认保留。")
        }
    }

    private var loginSection: some View {
        Section("登录") {
            TextField("手机号", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)

            TextField("短信验证码", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)

            Button(didRequestCode ? "重新获取验证码" : "获取验证码") {
                Task {
                    if await accountStore.requestSMSCode(phoneNumber: phoneNumber) {
                        didRequestCode = true
                        verificationCode = ""
                        statusMessage = "验证码已发送。"
                    }
                }
            }
            .disabled(!canRequestCode || accountStore.isLoading)

            Button("登录") {
                Task {
                    if await accountStore.login(phoneNumber: phoneNumber, code: verificationCode) {
                        phoneNumber = ""
                        verificationCode = ""
                        didRequestCode = false
                        statusMessage = "已登录。"
                    }
                }
            }
            .disabled(!canLogin || accountStore.isLoading)

            if accountStore.isLoading {
                ProgressView("处理中...")
            }

#if DEBUG
            Text("开发阶段验证码：123456")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
        }
    }

    private func profileSection(_ profile: AccountProfile) -> some View {
        Section("账号") {
            LabeledContent("手机号", value: profile.phoneMasked)
            LabeledContent("用户 ID", value: profile.userID)
            LabeledContent("会员状态", value: profile.membershipStatus.displayName)

            if let nickname = profile.nickname, !nickname.isEmpty {
                LabeledContent("昵称", value: nickname)
            }
        }
    }

    private var accountActionSection: some View {
        Section("账号操作") {
            Button("退出登录") {
                Task {
                    if await accountStore.logout() {
                        statusMessage = "已退出登录。"
                    }
                }
            }
            .disabled(accountStore.isLoading)

            Button("注销账号", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .disabled(accountStore.isLoading)
        }
    }

    private var normalizedPhoneInput: String {
        phoneNumber.filter(\.isNumber)
    }

    private var normalizedCodeInput: String {
        verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRequestCode: Bool {
        normalizedPhoneInput.count == 11
    }

    private var canLogin: Bool {
        canRequestCode && normalizedCodeInput.count >= 4
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { accountStore.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    accountStore.errorMessage = nil
                }
            }
        )
    }
}
