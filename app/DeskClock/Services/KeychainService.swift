//
//  KeychainService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 01/07/2026.
//

import Foundation
import Security

enum KeychainKey: String {
    case accessToken  = "deskclock.access_token"
    case refreshToken = "deskclock.refresh_token"
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case updateFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case invalidData
}

struct KeychainService {
    
    // Must match exactly the group configured in Keychain Sharing capability
    // on BOTH targets.
    // Group suffix — not sensitive, just a namespace. The Team ID prefix
    // is resolved at runtime below rather than hardcoded, so nothing
    // account-identifying lives in source control.
    private static let groupSuffix = "fr.oscarpalissot.deskclock.shared"
    
    private nonisolated static let accessGroup: String = {
        guard let teamID = resolveTeamIDPrefix() else {
            fatalError("Unable to resolve Keychain Team ID — check Keychain Sharing capability")
        }
        return "\(teamID).\(groupSuffix)"
    }()
    
    // Writes a throwaway probe item WITHOUT an explicit access group, so
    // the system assigns its default group ("<TeamID>.<bundleID>"), then
    // reads that back to extract the Team ID. Runs once per process.
    private nonisolated static func resolveTeamIDPrefix() -> String? {
        let probeAccount = "deskclock.keychain-probe"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: probeAccount,
            kSecValueData as String: Data("probe".utf8),
            kSecReturnAttributes as String: true // ask for attributes back, not just success/failure
        ]
        
        SecItemDelete(query as CFDictionary) // clean slate
        
        var result: AnyObject?
        let status = SecItemAdd(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              // This is the payoff: the group iOS actually assigned, in clear text.
              let defaultGroup = attributes[kSecAttrAccessGroup as String] as? String,
              // Team IDs never contain a dot, so splitting on the first one
              // isolates it regardless of what the bundle ID looks like.
                let teamID = defaultGroup.split(separator: ".").first else {
            return nil
        }
        
        SecItemDelete(query as CFDictionary) // don't leave the probe around
        return String(teamID)
    }
    
    // Keychain access is a synchronous system call with no inherent actor
    // affinity. Marked nonisolated so it can be called from any isolation
    // domain (main actor, custom actors, background tasks) without
    // requiring an await for actor hopping.
    nonisolated static func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String:   data,
            // allow to read the token while phone is locked, clock in or out triggered by goefencing
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            // allow to share Keychain between app and widget
            kSecAttrAccessGroup as String: accessGroup,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            let update: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.updateFailed(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
    }
    
    nonisolated static func read(_ key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
        case errSecItemNotFound:
            // Note: this status is also returned when the item exists but
            // its accessibility class prevents access in the current device
            // state (e.g. locked). Indistinguishable from true absence.
            throw KeychainError.notFound
        default:
            throw KeychainError.readFailed(status)
        }
    }
    
    nonisolated static func delete(_ key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
