//
//  APIManager.swift
//  Tester
//
//  Created by Darshan Shrikant on 14/10/22.
//

import Foundation

var developerMode: Bool { true }

enum ErrorMessages: String {
    case somethingWentWrong = "Something went wrong!"
}


enum ServiceMethod: String {
    case Get = "GET"
    case Post = "POST"
}

protocol Managable {
    
    func request<T: Codable>(
        url: URL,
        httpMethod: ServiceMethod,
        body: Data?,
        headers: [String:String]?,
        expectingReturnType: T.Type
    ) async throws -> T
}

                        
enum APIManagerError: Error {
    
    case conversionFailedToHTTPURLResponse
    case serilizationFailed
    case urlError(statuscode: Int)
    case somethingWentWrong
    case badURL
    
}

extension APIManagerError {
    
    var showableError: Self {
        switch self {
        case .urlError(_):
            return self
        default:
            return .somethingWentWrong
        }
    }
    
    ///Makes things easier
    var showableDescription: String {
        developerMode ? self.showableError.errorDescription : self.errorDescription
    }
    
    ///Default Error Description
    var errorDescription: String {
        switch self {
        case .conversionFailedToHTTPURLResponse:
            return "Typecasting failed."
        case .urlError(let code):
            return ErrorMessages.somethingWentWrong.rawValue + "underlying status code: \(code)"
        case .somethingWentWrong:
            return ErrorMessages.somethingWentWrong.rawValue
        case .serilizationFailed:
            return "JSONSerialization Failed"
        case .badURL:
            return "Malformed URL was sent to session."
        }
    }
}

extension Error {
    
    var description: String {
        ((self as? APIManagerError)?.errorDescription) ?? self.localizedDescription
    }
}

final class APIManager {
    
    public internal(set) var session: URLSession = .shared
    
    static let shared: Managable = APIManager()
    
    private init() { }
    
}

extension APIManager: Managable {
    
    func request<T: Codable>(
        url: URL,
        httpMethod: ServiceMethod,
        body: Data?,
        headers: [String:String]? = nil,
        expectingReturnType: T.Type = T.self
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        if let body = body,httpMethod != .Get {
            request.httpBody = body
        }
        request.addHeaders(from: headers)
        return try await self.responseHandler(
            session.data(for: request)
        )
    }
}


extension APIManager {
    
    func responseHandler<T: Codable>(
        _ dataWithResponse: (data: Data,response: URLResponse)
    ) async throws -> T {
        guard let response = dataWithResponse.response as? HTTPURLResponse else {
            throw APIManagerError.conversionFailedToHTTPURLResponse
        }
        try response.statusCodeChecker()
        return try JSONDecoder().decode(
            T.self,
            from: dataWithResponse.data
        )
    }
}

extension HTTPURLResponse {
    
    func statusCodeChecker() throws {
        switch self.statusCode {
        case 200...299:
            return
        default:
            throw APIManagerError.urlError(statuscode: self.statusCode)
        }
    }
}

extension URLRequest {
    
    mutating func addHeaders(from headers: [String: String]? = nil) {
        guard let headers = headers,
              !headers.isEmpty else {
            self.defaultHeaders()
            return
        }
        for header in headers {
            self.addValue(
                header.value,
                forHTTPHeaderField: header.key
            )
        }
        defaultHeaders()
    }
    
    mutating func defaultHeaders() {
        self.addValue(
            HeaderKeyValue.applicationJson.rawValue,
            forHTTPHeaderField: HeaderKeyValue.contentType.rawValue
        )
        self.addValue(
            HeaderKeyValue.applicationJson.rawValue,
            forHTTPHeaderField: HeaderKeyValue.accept.rawValue
        )
    }
}

enum HeaderKeyValue: String {
    case formUrlEncoded = "application/x-www-form-urlencoded"
    case contentType = "Content-Type"
    case accept = "Accept"
    case applicationJson = "application/json"
}



class AppServices<T: Codable> {
    
    var headers: [String: String]?
    var parameters: [String: String]?
    
    func call(
        with urlString: String,
        serviceMethod: ServiceMethod
    ) async throws -> T {
        guard let url = URL(string: urlString) else { throw APIManagerError.badURL }
        let body = try (parameters ?? [:]).serialize()
        return try await APIManager.shared.request(
            url: url,
            httpMethod: serviceMethod,
            body: body,
            headers: self.headers,
            expectingReturnType: T.self
        )
    }
}

public extension Dictionary {
    
    func serialize() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: self,
            options: .prettyPrinted
        )
    }
}
