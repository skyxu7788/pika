//
//  UserRepository.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import CoreData
import Foundation

struct UserRepository {
    let context: NSManagedObjectContext

    func findOrCreateUser(phoneNumber: String?, email: String?) throws -> User {
        let normalizedPhone = Self.normalizePhoneNumber(phoneNumber)
        let normalizedEmail = Self.normalizeEmail(email)

        guard normalizedPhone != nil || normalizedEmail != nil else {
            throw UserRepositoryError.missingIdentity
        }

        if let normalizedPhone, let user = try fetchUser(matching: "phoneNumber", value: normalizedPhone) {
            return user
        }

        if let normalizedEmail, let user = try fetchUser(matching: "email", value: normalizedEmail) {
            return user
        }

        let user = User(context: context)
        let now = Date()
        user.userId = UUID().uuidString
        user.phoneNumber = normalizedPhone
        user.email = normalizedEmail
        user.createdAt = now
        user.updatedAt = now
        try saveIfNeeded()
        return user
    }

    func hasCompletedOnboarding(_ user: User) -> Bool {
        user.photoData != nil && user.audioData != nil
    }

    func nextStep(for user: User) -> OnboardingStep {
        if user.photoData == nil {
            return .photo
        }

        if user.audioData == nil {
            return .voice
        }

        return .complete
    }

    func savePhoto(_ data: Data, for user: User) throws {
        user.photoData = data
        user.updatedAt = Date()
        try saveIfNeeded()
    }

    func saveAudio(_ data: Data, for user: User) throws {
        user.audioData = data
        user.updatedAt = Date()
        try saveIfNeeded()
    }

    static func normalizePhoneNumber(_ phoneNumber: String?) -> String? {
        guard let phoneNumber else { return nil }

        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = ""
        for character in trimmed {
            if character.isNumber {
                normalized.append(character)
            } else if character == "+", normalized.isEmpty {
                normalized.append(character)
            }
        }

        return normalized.isEmpty ? nil : normalized
    }

    static func normalizeEmail(_ email: String?) -> String? {
        guard let email else { return nil }

        let normalized = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalized.isEmpty ? nil : normalized
    }

    private func fetchUser(matching key: String, value: String) throws -> User? {
        let request = User.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", key, value)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request).first
    }

    private func saveIfNeeded() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

enum UserRepositoryError: Error {
    case missingIdentity
}
