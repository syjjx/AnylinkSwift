import SwiftUI

struct ProfileManagerView: View {
    @EnvironmentObject private var connectionManager: ConnectionManager
    @State private var selectedProfileID: UUID?
    @State private var draft = ProfileDraft()
    @State private var isCreating = false

    var body: some View {
        HStack(spacing: 0) {
            ProfileListView(
                profiles: connectionManager.gateways,
                selectedProfileID: selectedProfileID,
                isCreating: isCreating,
                onSelect: selectProfile,
                onNew: beginNewProfile
            )
            .frame(width: 230)

            Divider()

            ProfileEditorView(
                draft: $draft,
                isCreating: isCreating,
                canDelete: selectedProfileID != nil,
                onDelete: deleteProfile,
                onSave: saveProfile
            )
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.pageBackground)
        .frame(width: 720, height: 520)
        .onAppear {
            guard selectedProfileID == nil else { return }

            if let firstProfile = connectionManager.gateways.first {
                selectProfile(firstProfile)
            } else {
                isCreating = true
                draft = ProfileDraft()
            }
        }
        .onChange(of: connectionManager.gateways) { profiles in
            guard !isCreating else { return }

            if let selectedProfileID,
               let updatedProfile = profiles.first(where: { $0.id == selectedProfileID }) {
                draft = ProfileDraft(profile: updatedProfile)
            } else if let firstProfile = profiles.first {
                selectProfile(firstProfile)
            } else {
                self.selectedProfileID = nil
                isCreating = true
                draft = ProfileDraft()
            }
        }
    }

    private func selectProfile(_ profile: GatewayProfile) {
        isCreating = false
        selectedProfileID = profile.id
        draft = ProfileDraft(profile: profile)
    }

    private func beginNewProfile() {
        selectedProfileID = nil
        isCreating = true
        draft = ProfileDraft()
    }

    private func loadSelectedProfile() {
        guard let selectedProfileID,
              let profile = connectionManager.profile(with: selectedProfileID) else {
            if !isCreating {
                draft = ProfileDraft()
            }
            return
        }

        draft = ProfileDraft(profile: profile)
    }

    private func saveProfile() {
        guard let profileID = connectionManager.saveProfile(draft, id: selectedProfileID) else { return }
        isCreating = false
        selectedProfileID = profileID

        if let profile = connectionManager.profile(with: profileID) {
            draft = ProfileDraft(profile: profile)
        }
    }

    private func deleteProfile() {
        guard let selectedProfileID else { return }
        connectionManager.deleteProfile(id: selectedProfileID)
        self.selectedProfileID = connectionManager.gateways.first?.id
        isCreating = false
        loadSelectedProfile()
    }
}

private struct ProfileListView: View {
    let profiles: [GatewayProfile]
    let selectedProfileID: UUID?
    let isCreating: Bool
    let onSelect: (GatewayProfile) -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置列表")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 15)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(profiles) { profile in
                        Button {
                            onSelect(profile)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profile.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)

                                Text(profile.host)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(isSelected(profile) ? .white.opacity(0.75) : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .foregroundStyle(isSelected(profile) ? Color.white : Color.primary)
                            .background(
                                isSelected(profile) ? AppTheme.accent : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 9)
            }

            Spacer(minLength: 0)

            Button(action: onNew) {
                Label("新建配置", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background(AppTheme.controlBackground)
    }

    private func isSelected(_ profile: GatewayProfile) -> Bool {
        !isCreating && selectedProfileID == profile.id
    }
}

private struct ProfileEditorView: View {
    @Binding var draft: ProfileDraft
    let isCreating: Bool
    let canDelete: Bool
    let onDelete: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(isCreating ? "新建配置" : "配置详情")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("填写服务器登录信息和连接参数")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 18)

            VStack(spacing: 11) {
                ProfileField(title: "名称", placeholder: "请输入配置名称", text: $draft.name)
                ProfileField(title: "主机", placeholder: "请输入服务器地址", text: $draft.host)
                ProfileField(title: "用户名", placeholder: "请输入用户名", text: $draft.username)
                ProfileSecureField(title: "密码", placeholder: "请输入密码", text: $draft.password)
                ProfileField(title: "用户组", placeholder: "可选", text: $draft.group)
                ProfileField(title: "密钥", placeholder: "可选", text: $draft.secret)
            }

            Spacer(minLength: 20)

            HStack(spacing: 10) {
                Button("删除", role: .destructive, action: onDelete)
                    .disabled(!canDelete)

                Spacer()

                Button("保存", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ProfileField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(AppTheme.controlBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }
}

private struct ProfileSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)

            ZStack(alignment: .leading) {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.clear)
                    .tint(AppTheme.accent)
                    .textContentType(nil)
                    .autocorrectionDisabled()

                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                } else {
                    Text(String(repeating: "*", count: text.count))
                        .foregroundStyle(.primary)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(AppTheme.controlBackground, in: RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }
}
