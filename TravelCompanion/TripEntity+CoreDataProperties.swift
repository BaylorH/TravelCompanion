//
//  TripEntity+CoreDataProperties.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 4/16/24.
//
//

import Foundation
import CoreData


extension TripEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TripEntity> {
        return NSFetchRequest<TripEntity>(entityName: "TripEntity")
    }

    @NSManaged public var name: String?
    @NSManaged public var messages: NSSet?
    @NSManaged public var itineraryItems: NSSet?

}

// MARK: Generated accessors for messages
extension TripEntity {

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: MessageEntity)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: MessageEntity)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)

}

// MARK: Generated accessors for itineraryItems
extension TripEntity {

    @objc(addItineraryItemsObject:)
    @NSManaged public func addToItineraryItems(_ value: ItineraryItemEntity)

    @objc(removeItineraryItemsObject:)
    @NSManaged public func removeFromItineraryItems(_ value: ItineraryItemEntity)

    @objc(addItineraryItems:)
    @NSManaged public func addToItineraryItems(_ values: NSSet)

    @objc(removeItineraryItems:)
    @NSManaged public func removeFromItineraryItems(_ values: NSSet)

    // Clears all itinerary items from the trip
    func clearItineraryItems() {
        if let itineraryItems = self.itineraryItems {
            for item in itineraryItems {
                if let itineraryItem = item as? ItineraryItemEntity {
                    self.removeFromItineraryItems(itineraryItem)
                }
            }
            // Ensure to reset the itineraryItems to an empty set after removal
            self.itineraryItems = NSSet()
        }
    }
}

extension TripEntity : Identifiable {

}
