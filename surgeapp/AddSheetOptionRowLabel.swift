//
//  AddSheetOptionRowLabel.swift
//  surgeapp
//
//  Visual match for `AssistantAddOptionsSheet` / `optionButton` rows (used on onboarding upload step).
//

import SwiftUI

// MARK: - Row (same layout as add sheet)

/// Non-interactive label matching the add options sheet’s white card row.
private enum AddSheetOptionRowMetrics {
    static let iconSize: CGFloat = 48
    static let rowPadding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 16)
    static let cardShadow = Color.black.opacity(0.08)
}

struct AddSheetOptionRowLabel<Icon: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 14) {
            icon()
                .frame(width: AddSheetOptionRowMetrics.iconSize, height: AddSheetOptionRowMetrics.iconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.gray.opacity(0.45))
        }
        .padding(AddSheetOptionRowMetrics.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: AddSheetOptionRowMetrics.cardShadow, radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - Icons (match `AssistantAddOptionsSheet` option rows)

enum AddSheetAddOptionKind {
    case recordAudio
    case website
    case youTube
    case uploadDocument

    init?(title: String) {
        switch title {
        case "Record audio": self = .recordAudio
        case "Import from website": self = .website
        case "Add a YouTube link": self = .youTube
        case "Upload document": self = .uploadDocument
        default: return nil
        }
    }

    var subtitle: String? {
        switch self {
        case .uploadDocument: return "Any PDF, DOCX, PPT, TXT, etc!"
        case .recordAudio, .website, .youTube: return nil
        }
    }
}

enum AddSheetAddOptionIcons {
    fileprivate static let size: CGFloat = 48

    @ViewBuilder
    static func icon(for title: String) -> some View {
        if let kind = AddSheetAddOptionKind(title: title) {
            switch kind {
            case .recordAudio:
                recordAudioIcon
            case .website:
                websiteGlobeIcon(size: size)
            case .youTube:
                youTubeStyleLinkIcon(size: size)
            case .uploadDocument:
                uploadDocumentIcon
            }
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private static var recordAudioIcon: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.45, green: 0.32, blue: 0.88))
                .frame(width: AddSheetAddOptionIcons.size, height: AddSheetAddOptionIcons.size)
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private static var uploadDocumentIcon: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 0.45, green: 0.32, blue: 0.88))
                .frame(width: AddSheetAddOptionIcons.size, height: AddSheetAddOptionIcons.size)
            Text("DOC")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.bottom, 5)
        }
    }
}

// MARK: - YouTube + website icons (match AssistantView private structs)

private struct YouTubeStyleLinkIcon: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * size / 44, style: .continuous)
                .fill(Color(red: 0.9, green: 0.15, blue: 0.12))
                .frame(width: size, height: size)
            Image(systemName: "play.fill")
                .font(.system(size: 16 * size / 44, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1 * size / 44)
        }
    }
}

private struct WebsiteGlobeIcon: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * size / 44, style: .continuous)
                .fill(Color(red: 0.20, green: 0.50, blue: 0.85))
                .frame(width: size, height: size)
            Image(systemName: "globe")
                .font(.system(size: 20 * size / 44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private func youTubeStyleLinkIcon(size: CGFloat) -> some View {
    YouTubeStyleLinkIcon(size: size)
}

private func websiteGlobeIcon(size: CGFloat) -> some View {
    WebsiteGlobeIcon(size: size)
}
