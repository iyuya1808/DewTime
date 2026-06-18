import SwiftUI
import UserNotifications

// MARK: - Section header

struct SettingsSectionHeader: View {
    let title: String
    var caption: String? = nil
    var systemImage: String? = nil
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card container

struct SettingsCard<Content: View>: View {
    var borderColor: Color? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.dewSurface)
                    .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
            )
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(borderColor.opacity(0.35), lineWidth: 1.2)
                }
            }
    }
}

// MARK: - Status badge

struct SettingsStatusBadge: View {
    let text: String
    var tint: Color = .teal
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

// MARK: - Navigation row

struct SettingsNavigationRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String
    var iconTint: Color = .teal
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconTint.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Toggle row

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isDisabled: Bool = false

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isDisabled)
    }
}

// MARK: - Primary button

struct SettingsPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsThemeChip: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(theme.displayName)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.teal : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.teal.opacity(0.14) : Color.dewSurfaceSoft,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.teal, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SettingsLanguageChip: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(language.pickerLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? Color.teal : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? Color.teal.opacity(0.14) : Color.dewSurfaceSoft,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.teal, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.pickerLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AquariumThemeSwatch: View {
    let theme: AquariumTheme
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: swatchColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.8), lineWidth: 2.5)
                        }
                    }

                Text(theme.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var swatchColors: [Color] {
        let colors = theme.tankColors(isDark: colorScheme == .dark, isOverdue: false)
        return [colors.top, colors.middle]
    }
}

// MARK: - Notification status banner

struct NotificationAuthorizationBanner: View {
    let status: UNAuthorizationStatus

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bannerTint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: bannerIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(bannerTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.subheadline.weight(.bold))
                Text(bannerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(bannerTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(bannerTint.opacity(0.2), lineWidth: 1)
        }
    }

    private var bannerTint: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private var bannerIcon: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell.badge.fill"
        @unknown default: return "bell.fill"
        }
    }

    private var bannerTitle: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return L10n.NotificationSettings.bannerAuthorized
        case .denied: return L10n.NotificationSettings.bannerDenied
        case .notDetermined: return L10n.NotificationSettings.bannerNotDetermined
        @unknown default: return L10n.NotificationSettings.bannerUnknown
        }
    }

    private var bannerSubtitle: String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return L10n.NotificationSettings.bannerAuthorizedSubtitle
        case .denied:
            return L10n.NotificationSettings.bannerDeniedSubtitle
        case .notDetermined:
            return L10n.NotificationSettings.bannerNotDeterminedSubtitle
        @unknown default:
            return L10n.NotificationSettings.bannerUnknownSubtitle
        }
    }
}
