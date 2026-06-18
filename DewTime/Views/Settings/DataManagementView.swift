import SwiftUI

struct DataManagementView: View {
    @Environment(AppDataStore.self) private var store

    @State private var showResetAllConfirm = false
    @State private var showResetAquariumConfirm = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsSectionHeader(
                            title: L10n.DataManagement.saveStatus,
                            caption: L10n.DataManagement.saveStatusCaption,
                            systemImage: "externaldrive.fill",
                            tint: .teal
                        )

                        if store.isSaving || store.isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text(store.isLoading ? L10n.DataManagement.loading : L10n.DataManagement.saving)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(L10n.DataManagement.savedLocally)
                                    .font(.subheadline.weight(.medium))
                            }
                        }

                        if let message = store.errorMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(
                            title: L10n.DataManagement.partialReset,
                            caption: L10n.DataManagement.partialResetCaption,
                            systemImage: "arrow.counterclockwise",
                            tint: .orange
                        )

                        resetButton(
                            title: L10n.DataManagement.resetAquarium,
                            subtitle: L10n.DataManagement.resetAquariumSubtitle,
                            systemImage: "fish.fill"
                        ) {
                            showResetAquariumConfirm = true
                        }
                    }
                }

                SettingsCard(borderColor: .red) {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsSectionHeader(
                            title: L10n.DataManagement.dangerousOps,
                            caption: L10n.DataManagement.dangerousOpsCaption,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .red
                        )

                        Button {
                            showResetAllConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 40, height: 40)
                                    .background(Color.red.opacity(0.12), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.DataManagement.resetAll)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(L10n.DataManagement.resetAllSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle(L10n.DataManagement.title)
        .navigationBarTitleDisplayMode(.inline)
        .dewAppBackground()
        .alert(
            L10n.Common.saveError,
            isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .confirmationDialog(
            L10n.DataManagement.resetAquariumConfirm,
            isPresented: $showResetAquariumConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.DataManagement.resetButton, role: .destructive) { resetAquarium() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.DataManagement.resetAquariumMessage)
        }
        .confirmationDialog(
            L10n.DataManagement.resetAllConfirm,
            isPresented: $showResetAllConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.DataManagement.resetAllButton, role: .destructive) { resetAll() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.DataManagement.resetAllMessage)
        }
    }

    private func resetButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SettingsNavigationRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconTint: .orange,
                showsChevron: false
            )
        }
        .buttonStyle(.plain)
    }

    private func resetAquarium() {
        Task { await store.resetAquarium() }
    }

    private func resetAll() {
        Task { await store.resetAll() }
    }
}

#Preview {
    NavigationStack {
        DataManagementView()
    }
    .environment(AppDataStore())
}
