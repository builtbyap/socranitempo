//
//  AppScreen.swift
//  surgeapp
//

import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case notes
    case study
    case assistant
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .study: return "Study"
        case .assistant: return "Assistant"
        case .profile: return "Profile"
        }
    }

    var menuSymbol: String {
        switch self {
        case .notes: return "note.text"
        case .study: return "brain.head.profile"
        case .assistant: return "sparkles"
        case .profile: return "person.crop.circle"
        }
    }
}
