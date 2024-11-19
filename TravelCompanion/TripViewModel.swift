//
//  TripViewModel.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 3/17/24.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import DotEnv

class TripViewModel: ObservableObject {
    @Published var trips: [String: Trip] = [:]
    @Published var tripNames: [String] = [] // Store trip names separately
    
    var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchTrips()
        loadEnvVariables()
    }
    
    // Load environment variables using DotEnv
    func loadEnvVariables() {
        if let path = Bundle.main.path(forResource: ".env", ofType: nil) {
            do {
                try DotEnv.load(path: path)  // This loads the environment variables
                print("Environment variables loaded successfully")
                
                // Debugging: Print the specific environment variable
                if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
                    print("OPENAI_API_KEY: \(apiKey)")
                } else {
                    print("OPENAI_API_KEY not found in environment variables.")
                }
                
            } catch {
                print("Error loading .env file: \(error)")
            }
        } else {
            print("Could not find .env file.")
        }
    }

    
    // Retreive Core Data when app opened
    func fetchTrips() {
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        do {
            let results = try context.fetch(request)
            // Ensure no preexisting trips
            trips.removeAll()
            tripNames.removeAll()

            // Retrieve all entities in Core Data
            for entity in results {
                if let name = entity.name,
                    let messages = entity.messages?.allObjects as? [MessageEntity],
                    let itineraryItems = entity.itineraryItems?.allObjects as? [ItineraryItemEntity] {

                    let decodedMessages = messages.compactMap { $0.decodedMessage }
                    let decodedItineraryItems = itineraryItems.compactMap { $0.decodedItineraryItem }
                    
                    // Create Trip model
                    let trip = Trip(n: name, messages: decodedMessages, itineraryItems: decodedItineraryItems)
                        
                    trips[name] = trip
                    tripNames.append(name)
                }
            }
        } catch {
            print("Failed to fetch trips: \(error)")
        }
    }
    
    
    func addTrip(_ name: String) {
        // Create a new TripEntity in the context
        let tripEntity = TripEntity(context: context)
        tripEntity.name = name

        // Create a welcome message entity
        let welcomeMessage = MessageEntity(context: context)
        welcomeMessage.role = "system"
        welcomeMessage.content = "To get started, please tell me about any activities or places you're interested in. Be sure to include the name and the preferred start date & time for each activity."

        // Add the welcome message to the TripEntity
        tripEntity.addToMessages(welcomeMessage)

        // Save the new TripEntity to the Core Data context
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
        
        // Update trips collection to include this new trip
        let trip = Trip(n: name, messages: [Message(role: "system", content: welcomeMessage.content ?? "")], itineraryItems: [])
        trips[trip.name!] = trip
        tripNames.append(name)
    }

    func deleteTrip(n: String) {
        // Attempt to find the trip entity with the given name
        let fetchRequest: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", n)

        do {
            let results = try context.fetch(fetchRequest)
            if let tripEntity = results.first {
                // Delete the trip entity from the context
                context.delete(tripEntity)

                // Remove the trip from local storage
                trips[n] = nil
                tripNames.removeAll { $0 == n } // Remove the trip name from the list

                // Save the context to persist the deletion
                try context.save()
            } else {
                print("Trip not found in Core Data")
            }
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
        }
    }

    
    var count: Int {
        tripNames.count // Use the count of tripNames instead of trips
    }
    
    func search(n: String) -> Trip? {
        trips[n]
    }

    func addMessageToTrip(tripName: String, message: Message) {
        objectWillChange.send()  // Manually trigger the update
        
        // Fetch the TripEntity from Core Data
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", tripName)
        
        do {
            let results = try context.fetch(request)
            if let tripEntity = results.first {
                // Create a new MessageEntity object
                let messageEntity = MessageEntity(context: context)
                messageEntity.role = message.role
                messageEntity.content = message.content

                // Add the new message to the TripEntity
                tripEntity.addToMessages(messageEntity)
                
                // Save the context to persist changes
                try context.save()
                
                // Update the local trip model to reflect changes
                if let trip = trips[tripName] {
                    trip.messages.append(message)
                    trips[tripName] = trip  // Reassign to trigger @Published update
                }
            } else {
                print("Trip not found in Core Data")
            }
        } catch {
            print("Failed to fetch trip or save message: \(error)")
        }
    }


    func sendChatRequest(tripName: String, userMessage: String, displayMessage: Bool = true, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion("No URL")
            return
        }

        // Connect to the Chat GPT API
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            print("API key not found")
            return
        }

        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let messages = (trips[tripName]?.messages ?? []) + [Message(role: "user", content: userMessage)]
        let chatMessages = messages.map { ChatMessage(role: $0.role, content: $0.content) }
        let chatRequest = ChatRequest(model: "gpt-3.5-turbo", messages: chatMessages)
        
        // Encode request
        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(chatRequest)
            request.httpBody = jsonData
        } catch {
            print("Error encoding JSON:", error)
            completion("Failed to encode request")
            return
        }

        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("Error:", error?.localizedDescription ?? "Unknown error")
                completion("Network error")
                return
            }
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(ChatResponse.self, from: data)
                if let message = response.choices.first?.message.content {
                    DispatchQueue.main.async {
                        if displayMessage {
                            // Conversation between system and user
                            self?.objectWillChange.send()  // Notify before changes if visible
                            self?.addMessageToTrip(tripName: tripName, message: Message(role: "system", content: message))
                        }

                        completion(message)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion("No message received")
                    }
                }
            } catch {
                print("Failed to decode response:", error)
                completion("Failed to decode response")
            }
        }
        task.resume()
    }
    
    // Call for ChatGPT to inform information gathered from chat
    func fetchItineraryFromChatGPT(for tripName: String, completion: @escaping () -> Void) {
        let internalMessage = "What is the end date? If no end time, explicitly state 'End Time: TBD' instead of leaving it empty. Show me my itinerary for \(tripName). Please format it with these tags: [start]Activity: [activity]; Location: [location]; Start Time: [start_time]; End Time: [end_time][end]. Specify the location only by city name, not full address. Format the dates like this: h:mm a 'on' MMMM d, yyyy. Here are some examples: [start]Activity: Dinner with family; Location: Boise; Start Time: 9:00 PM on July 21, 2022; End Time: TBD[end][start]Activity: Dinner with uncle; Location: Boise; Start Time: 5:00 PM on July 22, 2022; End Time: TBD[end]"

        clearItineraryItems(for: tripName)
        
        sendChatRequest(tripName: tripName, userMessage: internalMessage, displayMessage: false) { response in
            self.parseAndUpdateItinerary(from: response, for: tripName)
            completion()
        }
    }
    
    // Parsing of ChatGPTs response of information gathered from chat
    func parseAndUpdateItinerary(from response: String, for tripName: String) {
        let pattern = "\\[start\\]Activity: (.*?); Location: (.*?); Start Time: (.*?); End Time: (.*?)\\[end\\]"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsrange = NSRange(response.startIndex..<response.endIndex, in: response)

        // Find range of words
        regex.enumerateMatches(in: response, options: [], range: nsrange) { match, flags, stop in
            guard let match = match,
                  let activityRange = Range(match.range(at: 1), in: response),
                  let locationRange = Range(match.range(at: 2), in: response),
                  let startTimeRange = Range(match.range(at: 3), in: response),
                  let endTimeRange = Range(match.range(at: 4), in: response) else {
                print("Could not parse itinerary item")
                return
            }

            // Parse for values
            let activity = String(response[activityRange])
            let location = String(response[locationRange])
            let startTimeString = String(response[startTimeRange])
            let endTimeString = String(response[endTimeRange])

            // Parse for date
            let dateTimeFormatter = DateFormatter()
            dateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateTimeFormatter.timeZone = TimeZone.current
            dateTimeFormatter.dateFormat = "h:mm a 'on' MMM d, yyyy"

            // Ensure parsed date is acceptable value to assign
            if let startTime = dateTimeFormatter.date(from: startTimeString) {
                var endTime: Date? = nil
                if endTimeString != "TBD" {
                    endTime = dateTimeFormatter.date(from: endTimeString)
                } else {
                    // Setting default duration of 2 hours if end time is TBD
                    endTime = Calendar.current.date(byAdding: .hour, value: 2, to: startTime)
                }
                addItineraryItem(to: tripName, location: location, activity: activity, startTime: startTime, endTime: endTime ?? startTime)
                print("REACHED")
            } else {
                print("Error parsing start time")
            }
        }
    }

    // Add item to itinerary for trip
    func addItineraryItem(to tripName: String, location: String, activity: String, startTime: Date, endTime: Date) {
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", tripName)

        do {
            let results = try context.fetch(request)
            if let tripEntity = results.first {
                // Create entity of item
                let newItemEntity = ItineraryItemEntity(context: context)
                newItemEntity.locationName = location
                newItemEntity.activity = activity
                newItemEntity.startTime = startTime
                newItemEntity.endTime = endTime

                // Save entity
                tripEntity.addToItineraryItems(newItemEntity)
                try context.save()

                // Update local model if necessary
                if let trip = trips[tripName] {
                    let newItem = ItineraryItem(locationName: location, activity: activity, startTime: startTime, endTime: endTime)
                    trip.itineraryItems?.append(newItem)
                    trips[tripName] = trip
                    objectWillChange.send()
                }
            }
        } catch {
            print("Failed to add itinerary item: \(error)")
        }
    }

    // Update values for item
    func updateItineraryItem(tripName: String, itemId: UUID, location: String, activity: String, startTime: Date, endTime: Date) {
        let itemRequest: NSFetchRequest<ItineraryItemEntity> = ItineraryItemEntity.fetchRequest()
        itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)

        do {
            let results = try context.fetch(itemRequest)
            if let itemEntity = results.first {
                // Resassign new values
                itemEntity.locationName = location
                itemEntity.activity = activity
                itemEntity.startTime = startTime
                itemEntity.endTime = endTime
                try context.save()

                // Update local model if necessary
                if let trip = trips[tripName], let index = trip.itineraryItems?.firstIndex(where: { $0.id == itemId }) {
                    let updatedItem = ItineraryItem(id: itemId, locationName: location, activity: activity, startTime: startTime, endTime: endTime)
                    trip.itineraryItems?[index] = updatedItem
                    trips[tripName] = trip
                    objectWillChange.send()
                }
            }
        } catch {
            print("Failed to update itinerary item: \(error)")
        }
    }

    // Delete item from itinerary
    func deleteItineraryItem(from tripName: String, itemId: UUID) {
        let itemRequest: NSFetchRequest<ItineraryItemEntity> = ItineraryItemEntity.fetchRequest()
        itemRequest.predicate = NSPredicate(format: "id == %@", itemId as CVarArg)

        do {
            let results = try context.fetch(itemRequest)
            if let itemEntity = results.first {
                // Deletion
                context.delete(itemEntity)
                try context.save()

                // Update local model
                if let trip = trips[tripName] {
                    trip.itineraryItems = trip.itineraryItems?.filter { $0.id != itemId }
                    trips[tripName] = trip
                    objectWillChange.send()
                }
            }
        } catch {
            print("Failed to delete itinerary item: \(error)")
        }
    }

    // Clear the itinerary for the trip
    func clearItineraryItems(for tripName: String) {
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", tripName)

        do {
            let results = try context.fetch(request)
            if let tripEntity = results.first {
                // Clear itinerary
                tripEntity.clearItineraryItems()
                try context.save()

                // Update local model
                if let trip = trips[tripName] {
                    trip.itineraryItems = []
                    trips[tripName] = trip
                    objectWillChange.send()
                }
            }
        } catch {
            print("Failed to clear itinerary items: \(error)")
        }
    }
}
