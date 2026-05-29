//
//  User.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import CoreData
import Foundation

@objc(User)
final class User: NSManagedObject {
    @NSManaged var userId: String
    @NSManaged var phoneNumber: String?
    @NSManaged var email: String?
    @NSManaged var photoData: Data?
    @NSManaged var audioData: Data?
    @NSManaged var location: String
    @NSManaged var status: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

extension User {
    @nonobjc class func fetchRequest() -> NSFetchRequest<User> {
        NSFetchRequest<User>(entityName: "User")
    }
}
