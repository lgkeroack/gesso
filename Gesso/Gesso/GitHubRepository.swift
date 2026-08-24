//
//  GitHubRepository.swift
//  Gesso
//
//  A repository accessible to the current user through the installed
//  Gesso GitHub App.
//

import Foundation

struct GitHubRepository: Identifiable, Codable, Equatable, Hashable {
    struct Owner: Codable, Equatable, Hashable {
        let login: String
        let avatarURL: String?

        enum CodingKeys: String, CodingKey {
            case login
            case avatarURL = "avatar_url"
        }
    }

    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let isPrivate: Bool
    let defaultBranch: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
        case htmlURL = "html_url"
    }
}
