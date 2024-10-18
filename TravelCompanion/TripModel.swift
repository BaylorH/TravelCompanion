//
//  TripModel.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 3/17/24.
//
import Foundation
import MapKit

// Main Structure
class Trip: ObservableObject {
    var name: String? = nil
    var messages: [Message] = []
    @Published var itineraryItems: [ItineraryItem]? = nil
    
    init(n: String, messages: [Message] = [], itineraryItems: [ItineraryItem] = []) {
        // Creates trip with default message, user given data, and empty itineraryItems
        let welcomeMessage: String = "Hello! I'm here to help you plan your trip to \(n). Let's start with an empty itinerary."

        self.name = n
        self.messages = [Message(role: "system", content: welcomeMessage)] + messages
        self.itineraryItems = itineraryItems
    }
}

// An itinerary consists of items ->
struct ItineraryItem: Hashable, Identifiable, Codable {
    var id: UUID = .init()
    var locationName: String
    var activity: String
    var startTime: Date
    var endTime: Date
}

// Toggle bar for top half selection of screen
enum ViewSelect: String, CaseIterable {
    case map = "Map"
    case itinerary = "Itinerary"
}

// Where role is system or user
struct Message: Codable, Identifiable {
    var id: UUID = .init()
    var role: String
    var content: String
}

// Information to store for a location
struct Location {
    var name: String
    var latitude: Double
    var longitude: Double
}

// Basic Message structure where role is either system or  user
struct ChatMessage: Codable {
    var role: String
    var content: String
}

// For actually sending the data over in method
struct ChatRequest: Codable {
    var model: String
    var messages: [ChatMessage]
}

// The Chat GPT API's response
struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            var role: String
            var content: String
        }
        var message: Message
    }
    var choices: [Choice]
}

//For map view point
struct IdentifiablePointAnnotation: Identifiable {
    let id = UUID()
    let annotation: MKPointAnnotation
}
