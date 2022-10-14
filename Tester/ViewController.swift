//
//  ViewController.swift
//  Tester
//
//  Created by Darshan Shrikant on 13/10/22.
//

import UIKit

struct Response<SomeCodable: Codable>: Codable {
    var data: SomeCodable?
}

struct Product: Codable {
    var id: Int?
    var title: String?
    var description: String?
    var price: Int?
    var rating: Float?
    var brand: String?
    var category: String?
}

struct Title: Codable {
    var title: String?
}

class ViewController: UIViewController {
    
    /// add parameters pass this if it's POST
    let parameters: [String:String] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        callWS()
    }
    
    /// add headers as per server requirements.
    func callWS() {
        Task {
            do {
                let service = AppServices<Product>.self()
                service.parameters = parameters
                let product = try await service.call(
                    with: "https://dummyjson.com/products/1",
                    serviceMethod: .Get
                )
                print(product)
            } catch let error {
                print(error.description)
            }
        }
    }
}

