//
//  RPCResponseHandler.swift
//  DahuaNVR
//
//  Protocol for handling API-specific RPC response processing
//

import Foundation

/// Protocol for handling RPC responses with API-specific logic
protocol RPCResponseHandler {
    /// The final response type that will be returned to the caller
    associatedtype ResponseType
    
    /// Processes the raw response data from the network request
    /// - Parameters:
    ///   - rawData: The raw Data received from the HTTP response
    ///   - decryptionKey: The symmetric key used for request encryption, available for response decryption
    /// - Returns: The processed response of type ResponseType
    /// - Throws: RPCError or other errors if processing fails
    func handle(rawData: Data, decryptionKey: Data?) throws -> ResponseType
}