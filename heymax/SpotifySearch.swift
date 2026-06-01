//
//  SpotifySearch.swift
//  heymax
//
//  Uses Spotify Web API to search for tracks and return their URI.
//  This lets us play the exact song the user asked for.

import Foundation

class SpotifySearch {
    static let shared = SpotifySearch()

    // Get your own at https://developer.spotify.com/dashboard (takes 2 min)
    // Create an app → copy Client ID and Client Secret
    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let clientSecret = "YOUR_SPOTIFY_CLIENT_SECRET"

    private var accessToken: String?
    private var tokenExpiry: Date?

    // MARK: - Search for a track, return its spotify URI

    func searchTrack(query: String) async -> String? {
        guard let token = await getToken() else {
            print("[SpotifySearch] Failed to get access token")
            return nil
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=1") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tracks = json["tracks"] as? [String: Any],
                  let items = tracks["items"] as? [[String: Any]],
                  let first = items.first,
                  let uri = first["uri"] as? String else {
                print("[SpotifySearch] No track found for: \(query)")
                return nil
            }
            print("[SpotifySearch] Found: \(uri)")
            return uri
        } catch {
            print("[SpotifySearch] Search error: \(error)")
            return nil
        }
    }

    // MARK: - Client Credentials token

    private func getToken() async -> String? {
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return nil }

        let credentials = "\(clientID):\(clientSecret)"
        guard let credData = credentials.data(using: .utf8) else { return nil }
        let base64 = credData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int else {
                print("[SpotifySearch] Token response invalid")
                return nil
            }

            self.accessToken = token
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
            return token
        } catch {
            print("[SpotifySearch] Token error: \(error)")
            return nil
        }
    }
}
