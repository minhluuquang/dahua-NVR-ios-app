import Foundation

protocol EncryptedRPCModule {
    var rpcBase: RPCBase { get }
}

extension EncryptedRPCModule {
    func sendEncrypted<TRequest: Codable, TResponse: Codable>(
        method: String,
        payload: TRequest,
        responseType: TResponse.Type
    ) async throws -> TResponse {
        return try await rpcBase.sendEncrypted(
            method: method,
            payload: payload,
            responseType: responseType
        )
    }
}