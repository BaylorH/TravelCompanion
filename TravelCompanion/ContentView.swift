//
//  ContentView.swift
//  TravelCompanion
//
//  Created by Baylor Harrison on 3/16/24.
//

import SwiftUI
import MapKit
import UIKit
import CoreData

// List of Trips by name
struct ContentView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @StateObject var tripModel: TripViewModel
    @State var name:String = ""
    @State var showingAddAlert = false
    
    init() {
        // Pass context to trip model
        _tripModel = StateObject(wrappedValue: TripViewModel(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack{
                // Trip list display
                if let tripsList = Array(tripModel.trips.values) as? [Trip], !tripsList.isEmpty {
                    List{
                        ForEach(tripModel.tripNames, id: \.self) { tripName in
                            HStack{
                                // If clicked, open up trip
                                NavigationLink(destination: DetailView(tripModel: tripModel, tripName: tripName)) {
                                    Text(tripName)
                                        .padding()
                                }
                                Spacer()
                            }
                        }
                    }
                        .listStyle(InsetGroupedListStyle())
                } else {
                    // No trips yet
                    HStack{
                        Text("Add a trip to get started")
                            .padding()
                        Spacer()
                    }
                }
                Spacer()
            }
            .navigationTitle("Your Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Pull up UI to add new trip
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Trip", isPresented: $showingAddAlert, actions: {
                // UI to add a new trip
                TextField("Location", text:$name)
                
                Button("Add Trip", action: {
                    // Add trip to model
                    tripModel.addTrip(name)
                    name = ""
                })
                Button("Cancel", role: .cancel, action: {
                    showingAddAlert = false;
                })
            })
        }
        .onAppear {
            tripModel.context = managedObjectContext
        }
    }
}

struct DetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tripModel: TripViewModel
    var tripName: String
    @State private var string: String = ""
    @State private var viewSelect:ViewSelect = .map
    @State private var gpt: String = ""
    @State private var showingDeleteAlert = false

    let viewSelects = ["Map", "Itinerary"]
    
    var body: some View {
        VStack{
            // Toggle to switch from map view to itinerary view
            Picker("Switch Views", selection: $viewSelect) {
                ForEach(ViewSelect.allCases, id: \.self) { view in
                    Text(view.rawValue).tag(view)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // Display selected view from toggle
            if viewSelect == .map {
                MapView(place: tripName)
            } else if viewSelect == .itinerary {
                ItineraryView(tripModel: tripModel, tripName: tripName)
            }
            
            // Top of message view
            Text("e.g. 7/21 hike Bogus 6pm. Say 'show itinerary' if it doesn't create how you hoped")
            // Message View
            ScrollView{
                ScrollViewReader { scrollView in
                    // Display all messages as a message view
                    ForEach(tripModel.trips[tripName]?.messages ?? [], id: \.id) { message in
                        MessageView(message: message)
                            .id(message.id)
                            .padding(5)
                    }
                    .onChange(of: tripModel.trips[tripName]?.messages.count) { _ in
                        guard let lastMessage = tripModel.trips[tripName]?.messages.last else { return }
                        if lastMessage.role == "system" && lastMessage.content.count > 300 {
                            // Set top of screen to top of last message
                            scrollView.scrollTo(lastMessage.id, anchor: .top)
                        } else {
                            // Set top of screen to bottom of last message
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    .onAppear{
                        // Set top of screen to bottom of last message
                        guard let lastMessage = tripModel.trips[tripName]?.messages.last else { return }
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            Divider()
            // Send message field
            HStack{
                TextField("Message...", text: self.$string, axis: .vertical)
                    .padding(5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    .onSubmit {
                        hideKeyboard()
                        // Send new messages when enter key pressed
                        if let _ = tripModel.search(n: tripName) {
                                tripModel.addMessageToTrip(tripName: tripName, message: Message(role: "user", content: string))
                                tripModel.sendChatRequest(tripName: tripName, userMessage: string) { responseMessage in
                                    string = "" // Reset message input field
                                }
                                string = "" // Ensure reset the message input field
                            tripModel.fetchItineraryFromChatGPT(for: tripName) {
                                // Render itinerary from chat
                            }
                            
                        } else {
                            print("Trip not found")
                        }
                         
                         // Ensure reset the message input field
                        string = ""
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
                Button {
                    hideKeyboard()
                    // Send new messages when paperplane button clicked
                    if let _ = tripModel.search(n: tripName) {
                        tripModel.addMessageToTrip(tripName: tripName, message: Message(role: "user", content: string))
                        tripModel.sendChatRequest(tripName: tripName, userMessage: string) { responseMessage in
                            string = "" // Reset the message input field
                        }
                        string = "" // Ensure reset the message input field
                        tripModel.fetchItineraryFromChatGPT(for: tripName) {
                            // Render itinerary from chat
                        }
                        
                    } else {
                        print("Trip not found")
                    }
                     
                    // Ensure reset the message input field
                    string = ""
                } label: {
                    Image(systemName: "paperplane")
                }

            }
            .padding()
        }
        .navigationTitle(tripName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Delete trip from list (this is located top right)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteAlert = true  // Ask for confirmation
                }) {
                 Image(systemName: "trash")
                     .foregroundColor(.red)
                     .padding()
                }
            }
        }.alert("Are you sure?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                tripModel.deleteTrip(n: tripName)  // Delete the trip if confirmed
                dismiss()
            }
        } message: {
            Text("Deleting this trip cannot be undone.")
        }

    }
}

struct MapView: View {
    var place: String
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    @State private var errorMessage: String?
    @State private var markers: [IdentifiablePointAnnotation] = []
    @State private var searchText = ""

        var body: some View {
            ZStack {
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                } else {
                    // Display map
                    Map(coordinateRegion: $region,
                        interactionModes: .all,
                        annotationItems: markers
                    ){ location in
                        // Display marker
                        MapMarker(coordinate: location.annotation.coordinate)
                    }
                        .onAppear {
                            lookupCoordinate()
                        }
                    VStack{
                        // Display search bar
                        searchBar
                        Spacer()
                    }
                }
            }
        }

    // Get coordinates of location
    private func lookupCoordinate() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(place) { placemarks, error in
            if let error = error {
                print("Geocode failed: \(error.localizedDescription)")
                self.errorMessage = "Geocode failed: \(error.localizedDescription)"
            } else if let placemark = placemarks?.first, let location = placemark.location {
                let newRegion = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                DispatchQueue.main.async {
                    self.region = newRegion
                }
            }
        }
    }
    
    // UI for search bar
    private var searchBar: some View {
        HStack {
            // Input field
            TextField("Search e.g., Pizza", text: $searchText, onCommit: performSearch)
                .foregroundColor(.black)
                .padding(10)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )

            // Enter button
            Button(action: performSearch) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.white)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }

    // Search button pressed
    private func performSearch() {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        searchRequest.region = region

        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            if let response = response {
                region = response.boundingRegion
                markers = response.mapItems.map { item in
                    IdentifiablePointAnnotation(annotation: createAnnotation(name: item.name ?? "", coordinate: item.placemark.coordinate))
                }
            } else if let error = error {
                print("Search error: \(error.localizedDescription)")
            }
            searchText = "" // Clear the search text after the search
        }
    }
    
    // Function to create an MKPointAnnotation
    private func createAnnotation(name: String, coordinate: CLLocationCoordinate2D) -> MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = name
        return annotation
    }
}

struct ItineraryView: View {
    @ObservedObject var tripModel: TripViewModel
    var tripName: String
    
    @State private var showingAddItineraryItem = false
    @State private var selectedEditItem: ItineraryItem?
    @State private var location = ""
    @State private var activity = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    
    // Organize itinerary items by date
    private var organizedItinerary: [(date: Date, items: [ItineraryItem])] {
        guard let items = tripModel.trips[tripName]?.itineraryItems else { return [] }
        let sortedItems = items.sorted(by: { $0.startTime < $1.startTime })
        let groupedItems = Dictionary(grouping: sortedItems, by: { Calendar.current.startOfDay(for: $0.startTime) })
        return groupedItems.map { (date: $0.key, items: $0.value) }.sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        ScrollView {
            Text("Select an item to edit")
            if organizedItinerary.isEmpty {
                Text("No items in itinerary")
                    .padding()
                    .foregroundColor(.secondary)
            } else {
                ForEach(organizedItinerary, id: \.date) { group in
                    HStack {
                        // Display date headers to group by start times
                        Text(DateFormatter.localizedString(from: group.date, dateStyle: .medium, timeStyle: .none))
                            .font(.headline)
                            .padding()
                        Spacer()
                    }
                    ForEach(group.items, id: \.self) { item in
                        // Display all items in itinerary
                        ItineraryItemView(item: item)
                            .onTapGesture {
                                self.selectedEditItem = item
                            }
                    }
                }
            }
            
            Button(action: {
                showingAddItineraryItem = true
            }) {
                Image(systemName: "plus")
                Text("Add New Item")
            }
            .padding()
            Spacer()
        }
        .sheet(item: $selectedEditItem) { item in
            // Open UI to edit item
            EditItineraryItemView(tripModel: tripModel, tripName: tripName, item: item)
        }
        .sheet(isPresented: $showingAddItineraryItem) {
            // UI to add new itinerary item
            NavigationView {
                Form {
                    Section(header: Text("Location & Activity")) {
                        TextField("Location", text: $location)
                        TextField("Activity", text: $activity)
                    }
                    Section(header: Text("Time")) {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("End Time", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                    }
                    Section {
                        Button("Add Itinerary Item") {
                            tripModel.addItineraryItem(to: tripName, location: location, activity: activity, startTime: startTime, endTime: endTime)
                            showingAddItineraryItem = false
                            location = "" // Reset fields after adding
                            activity = ""
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("New Itinerary Item")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingAddItineraryItem = false
                        }
                    }
                }
            }
        }
    }
}

// UI to edit itinerary item
struct EditItineraryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tripModel: TripViewModel
    var tripName: String
    var item: ItineraryItem
    
    @State var location = ""
    @State var activity = ""
    @State var startTime = Date()
    @State var endTime = Date()
    
    var body: some View {
        Form {
            TextField("Location", text: $location)
            TextField("Activity", text: $activity)
            DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            DatePicker("End Time", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
            
            Section {
                Button("Save Changes") {
                    // Update item in model
                    tripModel.updateItineraryItem(tripName: tripName, itemId: item.id, location: location, activity: activity, startTime: startTime, endTime: endTime)
                    dismiss()
                }
                
                Button("Delete Item") {
                    tripModel.deleteItineraryItem(from: tripName, itemId: item.id)
                    dismiss()
                }.foregroundColor(.red)
            }
        }
        .navigationTitle("Edit Item")
        .onAppear {
            location = item.locationName
            activity = item.activity
            startTime = item.startTime
            endTime = item.endTime
        }
    }
}

// Display for a single itinerary item
struct ItineraryItemView: View {
    var item: ItineraryItem
    
    var body: some View {
        HStack {
            // Times
            Text(item.startTime, style: .time) // Uses the .time style for date formatting
            Text("-")
            Text(item.endTime, style: .time)

            Text("  ")

            // Activity and Place
            Text(item.activity)
            Text("  ")
            Text(item.locationName).font(.subheadline).foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading) // Ensures the HStack takes up all available width
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

// Set up the look of the messages
struct MessageView: View {
    var message: Message
    
    var body: some View {
        Group {
            if message.role == "user" {
                // Messages from the user
                HStack {
                    Spacer()
                    Text(message.content)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .clipShape(ChatBubble(isFromUser: true))
                        .padding(.horizontal, 10)
                }
            } else {
                // Messages from system
                HStack {
                    Text(message.content)
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .clipShape(ChatBubble(isFromUser: false))
                        .padding(.horizontal, 10)
                    Spacer()
                }
            }
        }
    }
}

// Sets up the shape of the chat bubbles
struct ChatBubble: Shape {
    var isFromUser: Bool
    var cornerRadius: CGFloat = 10 // Adjust the corner radius as needed
    
    func path(in rect: CGRect) -> Path {
        let path: Path
        if isFromUser {
            path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        } else {
            path = Path { path in
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
                path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX + 20, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY - 10))
                path.closeSubpath()
            }
        }
        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
