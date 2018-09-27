//
//  VolumeController.swift
//  Books
//
//  Created by Daniela Parra on 9/25/18.
//  Copyright © 2018 Daniela Parra. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class VolumeController {
    
    // MARK: - CRUD Methods
    
    //Create volume from volume representation in search results.
    func createVolume(from volumeRepresentation: VolumeRepresentation, bookshelf: Bookshelf, context: NSManagedObjectContext = CoreDataStack.shared.mainContext) {
        //Create volume data model with convience initializer.
        let volume = Volume(volumeRepresentation: volumeRepresentation, bookshelf: bookshelf, context: context)
        
        //Adds volume to bookshelf in API.
        addVolumeToBookselfInServer(volume: volume, bookshelf: bookshelf)
        
        do {
            try context.save()
        } catch {
            NSLog("Error saving newly created volume: \(error)")
        }
    }
    
    //Update book with data entered from user.
    func updateVolume(volume: Volume, myReview: String, myRating: Int, hasRead: Bool) {
        volume.myReview = myReview
        volume.myRating = Int16(myRating)
        volume.hasRead = hasRead
        
        //Use volume's original context to save to persistent store or use the main context.
        let context = volume.managedObjectContext ?? CoreDataStack.shared.mainContext
        do {
            try context.save()
        } catch {
            NSLog("Error saving newly created volume: \(error)")
        }
    }
    
    //Move volume to another bookshelf.
    func moveVolume(volume: Volume, from oldBookshelf: Bookshelf, to newBookshelf: Bookshelf) {
        let moc = CoreDataStack.shared.mainContext
        
        //Add volume to new bookshelf in persistent store.
        
        //Remove volume from old bookshelf in persistent store.
        moc.delete(volume) //This doesn't seem right?
        
        //Move volume in server.
        moveVolumeToAnotherBookshelfinServer(volume: volume, oldBookshelf: oldBookshelf, newBookshelf: newBookshelf)
    }
    
    //Delete book from bookshelf.
    func delete(volume: Volume, bookshelf: Bookshelf) {
        let moc = CoreDataStack.shared.mainContext
        
        deleteVolumeFromBookselfInServer(volume: volume, bookshelf: bookshelf)
        
        //This only works if it only exists in one bookshelf, what about > 1?
        moc.delete(volume)
        
        do {
            try CoreDataStack.shared.save(context: moc)
        } catch {
            moc.reset()
            NSLog("Error saving moc after deleting volume: \(error)")
        }
    }
    
    // MARK: - Networking (Books API)
    
    //Search query for books with given search term.
    func searchBooks(searchTerm: String, completion: @escaping (Error?) -> Void) {
        
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        
        let queryParameters = ["q": searchTerm]
        
        components?.queryItems = queryParameters.map({URLQueryItem(name: $0.key, value: $0.value)})
        
        guard let requestURL = components?.url else {
            completion(NSError())
            return
        }
        
        URLSession.shared.dataTask(with: requestURL) { (data, _, error) in
            if let error = error {
                NSLog("Error searching for books with search term \(searchTerm): \(error)")
                completion(error)
                return
            }
            
            guard let data = data else {
                NSLog("No data returned from data task")
                completion(NSError())
                return
            }
            
            do {
                let searchResults = try JSONDecoder().decode(VolumeSearchResults.self, from: data)
                self.volumeSearchResults = searchResults.items
            } catch {
                NSLog("Error decoding data: \(error)")
                completion(error)
                return
            }
            completion(nil)
        }.resume()
        
    }
    
    //Add volume to an existing bookshelf in server.
    func addVolumeToBookselfInServer(volume: Volume, bookshelf: Bookshelf) {
        
        let requestURL = betterBaseURL.appendingPathComponent(String(bookshelf.id)).appendingPathComponent("addVolume")
        
        var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: true)
        
        let queryParameters = ["volumeId": volume.id]
        
        components?.queryItems = queryParameters.map({URLQueryItem(name: $0.key, value: $0.value)})
        
        guard let newRequestURL = components?.url else { return }
        
        var request = URLRequest(url: newRequestURL)
        request.httpMethod = HTTPMethod.post.rawValue
        
        GoogleBooksAuthorizationClient.shared.addAuthorization(to: request) { (request, error) in
            if let error = error {
                NSLog("Error adding authorization to request: \(error)")
                return
            }
            guard let request = request else { return }
            
            URLSession.shared.dataTask(with: request, completionHandler: { (data, _, error) in
                if let error = error {
                    NSLog("Error POSTing volume in bookshelf: \(error)")
                    return
                }
            }).resume()
        }
    }
    
    //Update volume's position in a bookshelf.
    //developers.google.com/books/docs/v1/reference/mylibrary/bookshelves/moveVolume
    
    
    //Delete volume from an existing bookshelf in server.
    func deleteVolumeFromBookselfInServer(volume: Volume, bookshelf: Bookshelf) {
        
        let requestURL = betterBaseURL.appendingPathComponent(String(bookshelf.id)).appendingPathComponent("removeVolume")
        
        var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: true)
        
        let queryParameters = ["volumeId": volume.id]
        
        components?.queryItems = queryParameters.map({URLQueryItem(name: $0.key, value: $0.value)})
        
        guard let newRequestURL = components?.url else { return }
        
        var request = URLRequest(url: newRequestURL)
        request.httpMethod = HTTPMethod.post.rawValue
        
        GoogleBooksAuthorizationClient.shared.addAuthorization(to: request) { (request, error) in
            if let error = error {
                NSLog("Error adding authorization to request: \(error)")
                return
            }
            guard let request = request else { return }
            
            URLSession.shared.dataTask(with: request, completionHandler: { (data, _, error) in
                if let error = error {
                    NSLog("Error deleting volume from bookshelf: \(error)")
                    return
                }
                
            }).resume()
        }
    }
    
    //Move volume to another bookshelf in server.
    func moveVolumeToAnotherBookshelfinServer(volume: Volume, oldBookshelf: Bookshelf, newBookshelf: Bookshelf) {
        
        addVolumeToBookselfInServer(volume: volume, bookshelf: newBookshelf)
        deleteVolumeFromBookselfInServer(volume: volume, bookshelf: oldBookshelf)
        
    }
    
    func displayImage(volume: Volume, imageView: UIImageView) {
        
        guard let thumbnailString = volume.image else { return }
        let url = URL(string: thumbnailString)!
        
        URLSession.shared.dataTask(with: url) { (data, _, error) in
            if let error = error {
                NSLog("Error: \(error)")
            }
            
            guard let data = data else { return }
            
            guard let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
    }
    
    // MARK: - Properties
    
    var volumeSearchResults: [VolumeRepresentation] = []
    
    private let baseURL = URL(string: "https://www.googleapis.com/books/v1/volumes")!
    private let betterBaseURL = URL(string: "https://www.googleapis.com/books/v1/mylibrary/bookshelves")!
}
