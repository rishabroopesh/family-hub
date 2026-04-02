import Foundation
import Security

enum APIError: LocalizedError {
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please log in again."
        case .notFound: return "Resource not found."
        case .serverError(let msg): return "Server error: \(msg)"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidURL: return "Invalid URL."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let keychainKey = "familyhub_auth_token"
    private let baseURLKey = "familyhub_base_url"
    private let defaultBaseURL = "http://192.168.1.100:8000"

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    var token: String? {
        return keychainRead(key: keychainKey)
    }

    func saveToken(_ token: String) {
        keychainWrite(key: keychainKey, value: token)
    }

    func deleteToken() {
        keychainDelete(key: keychainKey)
    }

    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            NotificationCenter.default.post(name: .unauthorizedResponse, object: nil)
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(message)
        }
    }

    func requestVoid(_ endpoint: String, method: String, body: Data? = nil) async throws {
        guard let url = URL(string: baseURL + endpoint) else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .unauthorizedResponse, object: nil)
            throw APIError.unauthorized
        }

        if !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(message)
        }
    }

    // MARK: - Keychain helpers

    private func keychainWrite(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        keychainDelete(key: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainRead(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private func keychainDelete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
