import Foundation
import Testing
@testable import DewTime

@Suite("Localization guard")
struct LocalizationGuardTests {
    private static let scanRoots = [
        "DewTime/Views",
        "DewTime/Models",
        "DewTime/Support",
        "DewTimeLiveActivityExtension",
    ]

    private static let allowedPathFragments = [
        "L10n.swift",
        "L10nModels.swift",
        "L10nGarden.swift",
        "LocalizationGuardTests.swift",
    ]

    private static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x9FFF).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
        }
    }

    private static func isUserFacingLine(_ line: String) -> Bool {
        line.contains("Text(\"") ||
            line.contains("Label(\"") ||
            line.contains("Button(\"") ||
            line.contains("navigationTitle(\"") ||
            line.contains("accessibilityLabel(\"")
    }

    @Test("No hardcoded Japanese in user-facing UI")
    func noHardcodedJapaneseInUserFacingUI() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var violations: [String] = []

        for root in Self.scanRoots {
            let dir = repoRoot.appendingPathComponent(root)
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: nil
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let path = fileURL.path
                if Self.allowedPathFragments.contains(where: { path.contains($0) }) { continue }
                if path.contains("/Tests/") { continue }

                let source = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = source.components(separatedBy: .newlines)

                for (index, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") { continue }
                    if trimmed.hasPrefix("#Preview") { continue }
                    if line.contains("default:") && line.contains("tr(") { continue }
                    guard Self.isUserFacingLine(line), Self.containsJapanese(line) else { continue }
                    violations.append("\(fileURL.lastPathComponent):\(index + 1): \(trimmed)")
                }
            }
        }

        if !violations.isEmpty {
            Issue.record("Hardcoded Japanese found:\n\(violations.joined(separator: "\n"))")
        }
        #expect(violations.isEmpty)
    }

    @Test("LocalizationManager resolves different languages")
    func localizationManagerResolvesLanguages() {
        let manager = LocalizationManager.shared
        let previous = manager.language

        manager.language = .ja
        let jaTimer = L10n.Tab.timer

        manager.language = .en
        let enTimer = L10n.Tab.timer

        manager.language = previous

        #expect(jaTimer == "タイマー")
        #expect(enTimer == "Timer")
    }
}
