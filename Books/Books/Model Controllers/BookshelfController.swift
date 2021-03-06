//
//  BookshelfController.swift
//  Books
//
//  Created by Daniela Parra on 9/25/18.
//  Copyright © 2018 Daniela Parra. All rights reserved.
//

import Foundation
import CoreData

class BookshelfController {

    
    // MARK: - Networking (Books API)
    
    //Get all bookshelves from user's profile.
    func fetchBookshelvesFromServer(completion: @escaping (Error?) -> Void = { _ in }) {
        
        let requestURL = baseURL
        let request = URLRequest(url: requestURL)
        
        GoogleBooksAuthorizationClient.shared.addAuthorization(to: request) { (request, error) in
            if let error = error {
                NSLog("Error adding authorization to request: \(error)")
                return
            }
            guard let request = request else { return }
            
            URLSession.shared.dataTask(with: request) { (data, _, error) in
                if let error = error {
                    NSLog("Error fetching data for bookshelves: \(error)")
                    completion(error)
                    return
                }
                guard let data = data else {
                    NSLog("No data returned from data task")
                    completion(NSError())
                    return
                }

                do {
                    let searchResults = try JSONDecoder().decode(BookshelfResults.self, from: data)
                    self.bookshelfRepresentations = searchResults.items
                    
                    let backgroundContext = CoreDataStack.shared.container.newBackgroundContext()
                    
                    backgroundContext.performAndWait {

                        for bookshelfRep in self.bookshelfRepresentations {
                            
                            let idString = String(bookshelfRep.id)
                            let bookshelf = self.fetchSingleBookshelfFromPersistentStore(id: idString, context: backgroundContext)
                            
                            if let bookshelf = bookshelf {
                                if bookshelf != bookshelfRep {
                                    //Update bookshelf with bookshelf rep's title
                                    bookshelf.title = bookshelfRep.title
                                }
                            } else {
                                Bookshelf(bookshelfRepresentation: bookshelfRep, context: backgroundContext)
                            }
                        }
                        
                        do {
                            try CoreDataStack.shared.save(context: backgroundContext)
                        } catch {
                            NSLog("Error saving after fetching bookshelves: \(error)")
                        }
                    
                    }
                } catch {
                    NSLog("Error decoding data: \(error)")
                    completion(error)
                    return
                }
                completion(nil)
            }.resume()
        }
    }
    
    // MARK: - Core Data Persistence
    
    //Fetch a single bookshelf to compare with bookshelf from API
    func fetchSingleBookshelfFromPersistentStore(id: String, context: NSManagedObjectContext) -> Bookshelf? {
        
        let fetchRequest: NSFetchRequest<Bookshelf> = Bookshelf.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        var bookshelf: Bookshelf? = nil
        context.performAndWait {
            do {
                bookshelf = try context.fetch(fetchRequest).first
            } catch {
                NSLog("Error fetching entry with given identifier: \(error)")
            }
        }
        return bookshelf
    }
    
    //Fetch volumes for a given bookshelf.
    func fetchVolumesforBookshelfFromServer(bookshelf: Bookshelf, completion: @escaping (Error?) -> Void) {
        
        let requestURL = baseURL.appendingPathComponent(String(bookshelf.id)).appendingPathComponent("volumes")

        let request = URLRequest(url: requestURL)
        
        GoogleBooksAuthorizationClient.shared.addAuthorization(to: request) { (request, error) in
            if let error = error {
                NSLog("Error adding authorization to request: \(error)")
                return
            }
            guard let request = request else { return }
            
            URLSession.shared.dataTask(with: request) { (data, _, error) in
                if let error = error {
                    NSLog("Error fetching data for volumes of bookshelf: \(error)")
                    return
                }
                
                guard let data = data else {
                    NSLog("No data returned from data task")
                    return
                }
                
                do {
                    let volumeResults = try JSONDecoder().decode(VolumeSearchResults.self, from: data)
                    let volumeReps = volumeResults.items
                    print(volumeReps)
                    
                    let backgroundContext = CoreDataStack.shared.container.newBackgroundContext()
                    
                    backgroundContext.performAndWait {
                        for volumeRep in volumeReps {
                            
                            if let volume = self.fetchSingleVolumeFromPersistentStore(id: volumeRep.id
                                , context: backgroundContext) {
                                if volume != volumeRep {
                                    //update volume
                                }
                            } else {
                                Volume(volumeRepresentation: volumeRep, bookshelf: bookshelf, context: backgroundContext)
                            }
                        }
                        do {
                            try CoreDataStack.shared.save(context: backgroundContext)
                        } catch {
                            NSLog("\(error)")
                        }
                    }
                    
                } catch {
                    NSLog("Error decoding data: \(error)")
                    return
                }
            }.resume()
        }
    }
    
    func fetchSingleVolumeFromPersistentStore(id: String, context: NSManagedObjectContext) -> Volume? {
        
        let fetchRequest: NSFetchRequest<Volume> = Volume.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        var volume: Volume? = nil
        context.performAndWait {
            do {
                volume = try context.fetch(fetchRequest).first
            } catch {
                NSLog("Error fetching entry with given identifier: \(error)")
            }
        }
        return volume
    }
    
    // MARK: - Properties
    
    var bookshelfRepresentations: [BookshelfRepresentation] = []
    
    private let baseURL = URL(string: "https://www.googleapis.com/books/v1/mylibrary/bookshelves")!
}
