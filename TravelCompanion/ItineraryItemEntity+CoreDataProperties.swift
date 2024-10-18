//
//  ItineraryItemEntity+CoreDataProperties.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 4/16/24.
//
//

import Foundation
import CoreData


extension ItineraryItemEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ItineraryItemEntity> {
        return NSFetchRequest<ItineraryItemEntity>(entityName: "ItineraryItemEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var locationName: String?
    @NSManaged public var activity: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var trip: TripEntity?

    var decodedItineraryItem: ItineraryItem? {
        guard let locationName = locationName, let activity = activity, let startTime = startTime, let endTime = endTime else { return nil }
        return ItineraryItem(id: id ?? UUID(), locationName: locationName, activity: activity, startTime: startTime, endTime: endTime)
    }
    
    // Create entity to store
    convenience init(locationName: String, activity: String, startTime: Date, endTime: Date, context: NSManagedObjectContext) {
        self.init(context: context)
        self.locationName = locationName
        self.activity = activity
        self.startTime = startTime
        self.endTime = endTime
    }
}

extension ItineraryItemEntity : Identifiable {
    
}
