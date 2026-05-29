//
//  CompleteStepProfile.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation

struct CompleteStepProfile {
    let userId: String
    let displayName: String
    let updatedAt: Date
    let location: String
    let status: String
    let photoData: Data?

    var publicProfilePath: String {
        "PIKA.ME/LUNA-SMITH/\(userId.lowercased())"
    }

    init(
        userId: String,
        displayName: String = "SEMI",
        updatedAt: Date,
        location: String,
        status: String,
        photoData: Data?
    ) {
        self.userId = userId
        self.displayName = displayName
        self.updatedAt = updatedAt
        self.location = location
        self.status = status
        self.photoData = photoData
    }

    init(user: User) {
        self.init(
            userId: user.userId,
            updatedAt: user.updatedAt,
            location: user.location,
            status: user.status,
            photoData: user.photoData
        )
    }
}
