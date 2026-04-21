//
//  AppScreen.swift
//  surgeapp
//

import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case notes
    case study
    case assistant
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .study: return "Study"
        case .assistant: return "Assistant"
        case .library: return "Library"
        }
    }

    var menuSymbol: String {
        switch self {
        case .notes: return "note.text"
        case .study: return "brain.head.profile"
        case .assistant: return "sparkles"
        case .library: return "books.vertical"
        }
    }
}
