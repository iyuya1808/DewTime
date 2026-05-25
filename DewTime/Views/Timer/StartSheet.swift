import SwiftUI

// MARK: - StartSheet

/// スタートボタン押下時に表示する出発時刻確認・設定シート。
/// クイックチップ（+N分後）とホイールピッカーを1画面に並べ、
/// ユーザーが時刻を確定してからタイマーを開始する。
struct StartSheet: View {

    // MARK: - Props
    let scheduleName: String
    let currentTime: Date
    let onStart: (Date) -> Void
    let onCancel: () -> Void

    // MARK: - State
    @State private var selectedTime: Date
    @State private var selectedChip: Int?         // 選択中のクイックオフセット(分)
    @State private var suppressChipClear = false  // チップ変更によるpicker更新でチップ選択を消さないフラグ
    @State private var appear = false             // 入場アニメ用

    // MARK: - Constants
    private let chips: [(label: String, minutes: Int)] = [
        ("15分後", 15), ("30分後", 30), ("45分後", 45), ("1時間後", 60)
    ]

    // MARK: - Init
    init(
        scheduleName: String,
        currentTime: Date,
        onStart: @escaping (Date) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.scheduleName = scheduleName
        self.currentTime = currentTime
        self.onStart = onStart
        self.onCancel = onCancel
        _selectedTime = State(initialValue: currentTime)
    }

    // MARK: - Derived
    private var minutesFromNow: Int {
        max(0, Int(selectedTime.timeIntervalSince(.now)) / 60)
    }

    private var isPast: Bool { selectedTime < .now }

    // MARK: - Body
    var body: some View {
        ZStack {
            LinearGradient.dewTimeSheet
                .ignoresSafeArea()

            // オーロラグロー
            auroraLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                dragHandle

                headerSection
                    .padding(.top, 4)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)

                heroCard
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                quickChipsSection
                    .padding(.horizontal, 24)
                    .padding(.top, 26)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)

                orDivider
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .opacity(appear ? 1 : 0)

                wheelPickerSection
                    .padding(.top, 0)
                    .opacity(appear ? 1 : 0)

                Spacer(minLength: 0)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                appear = true
            }
        }
        .onChange(of: selectedTime) { _, _ in
            guard !suppressChipClear else { return }
            selectedChip = nil
        }
    }

    // MARK: - Aurora Layer
    private var auroraLayer: some View {
        ZStack {
            Circle()
                .fill(Color.dewBlue.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 72)
                .offset(x: 90, y: -160)
            Circle()
                .fill(Color(red: 0.48, green: 0.40, blue: 1.0).opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -100, y: -90)
            Circle()
                .fill(Color(red: 0.10, green: 0.60, blue: 1.0).opacity(0.07))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -30, y: 200)
        }
    }

    // MARK: - Drag Handle
    private var dragHandle: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.dewBlue.opacity(0.5), .white.opacity(0.22)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 38, height: 4)
            .padding(.top, 14)
            .padding(.bottom, 20)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 5) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.dewBlue.opacity(0.30), Color(red: 0.48, green: 0.40, blue: 1.0).opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(Color.dewBlue.opacity(0.30), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Image(systemName: "timer.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.dewBlue)
                }

                Text("出発時刻を確認")
                    .font(.title2.weight(.bold))
            }
            Text(scheduleName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.40))
                .tracking(0.4)
        }
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 14) {
            // 大きな時刻表示
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Image(systemName: "figure.walk.departure")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.white.opacity(0.75))

                Text(selectedTime, format: .dateTime.hour().minute())
                    .font(.system(size: 68, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: Color.dewBlue.opacity(0.35), radius: 14)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTime)
            }

            // バッジ
            if isPast {
                badge(
                    icon: "exclamationmark.triangle.fill",
                    text: "出発時刻を過ぎています",
                    tint: .orange
                )
            } else if minutesFromNow == 0 {
                badge(
                    icon: "bolt.fill",
                    text: "今すぐ出発",
                    tint: Color.dewBlue
                )
            } else {
                badge(
                    icon: "clock",
                    text: "今から \(minutesFromNow) 分後に出発",
                    tint: Color.dewBlue
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.25), Color.dewBlue.opacity(0.12), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.dewBlue.opacity(0.10), radius: 20, y: 6)
    }

    private func badge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.20), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.60), lineWidth: 1.5))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: minutesFromNow)
    }

    // MARK: - Quick Chips
    private var quickChipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("クイック設定")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                // 現在の設定に戻すボタン
                Button {
                    tapChip(nil, time: currentTime)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2.weight(.semibold))
                        Text("元の時刻")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(
                        selectedChip == nil && selectedTime == currentTime
                            ? Color.dewBlue
                            : .white.opacity(0.4)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(chips, id: \.minutes) { chip in
                    chipButton(label: chip.label, minutes: chip.minutes)
                }
            }
        }
    }

    private func chipButton(label: String, minutes: Int) -> some View {
        let isSelected = selectedChip == minutes
        return Button {
            tapChip(minutes, time: Date.now.addingTimeInterval(Double(minutes) * 60))
        } label: {
            VStack(spacing: 2) {
                Text("+\(minutes < 60 ? "\(minutes)分" : "1時間")")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                Text(isSelected ? "✓" : label.components(separatedBy: "後").first.map { $0 + "後" } ?? label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [Color.dewBlue, Color(red: 0.22, green: 0.47, blue: 0.90)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.dewBlue.opacity(0.0) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? Color.dewBlue.opacity(0.40) : .clear, radius: 10, y: 4)
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }

    private func tapChip(_ minutes: Int?, time: Date) {
        suppressChipClear = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedChip = minutes
            selectedTime = time
        }
        Task { @MainActor in suppressChipClear = false }
    }

    // MARK: - Divider
    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 0.5)
            Text("または時刻を直接指定")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.30))
                .fixedSize()
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 0.5)
        }
    }

    // MARK: - Wheel Picker
    private var wheelPickerSection: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { selectedTime },
                set: { newVal in
                    selectedTime = newVal
                    // チップとの同期は onChange で処理
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .colorScheme(.dark)
        .frame(maxHeight: 160)
        .clipped()
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Start
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onStart(selectedTime)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.body.weight(.semibold))
                    Text("スタート！")
                        .font(.title3.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [Color.dewBlue, Color(red: 0.22, green: 0.47, blue: 0.90), Color(red: 0.18, green: 0.28, blue: 0.80)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                )
                .shadow(color: Color.dewBlue.opacity(0.18), radius: 8, y: 3)
            }

            // Cancel
            Button {
                onCancel()
            } label: {
                Text("キャンセル")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    StartSheet(
        scheduleName: "朝の通勤",
        currentTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!,
        onStart: { _ in },
        onCancel: {}
    )
}
