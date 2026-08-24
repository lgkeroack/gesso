//
//  ChatMessage.swift
//  Gesso
//

import Foundation
import UIKit

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
        case activity
        case question
    }

    let id = UUID()
    let role: Role
    var text: String
    let image: UIImage?
    var options: [String]? = nil
    var selectedOption: String? = nil
}
