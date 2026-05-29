//
//  CompleteStepStore.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation

@MainActor
final class CompleteStepStore: ObservableObject {
    @Published private(set) var profile: CompleteStepProfile?
    @Published var errorMessage: String?

    private let userId: String
    private let repository: UserRepository?

    init(userId: String, repository: UserRepository) {
        self.userId = userId
        self.repository = repository
        fetchUser()
    }

    init(profile: CompleteStepProfile) {
        self.userId = profile.userId
        self.repository = nil
        self.profile = profile
    }

    func fetchUser() {
        guard let repository else { return }

        do {
            profile = try repository.fetchUser(userId: userId).map(CompleteStepProfile.init(user:))
            errorMessage = profile == nil ? "Could not find your profile." : nil
        } catch {
            profile = nil
            errorMessage = "Could not load your profile."
        }
    }
}
