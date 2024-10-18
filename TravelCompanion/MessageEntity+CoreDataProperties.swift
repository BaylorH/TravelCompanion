//
//  MessageEntity+CoreDataProperties.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 4/16/24.
//
//

import Foundation
import CoreData


extension MessageEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var role: String?
    @NSManaged public var content: String?
    @NSManaged public var trip: TripEntity?

    var decodedMessage: Message? {
        guard let content = content else { return nil }
        return Message(id: id ?? UUID(), role: role ?? "", content: content)
    }
    
    // Create object to store
    convenience init(role: String, content: String, context: NSManagedObjectContext) {
        self.init(context: context)
        self.role = role
        self.content = content
    }
}

extension MessageEntity : Identifiable {

}
