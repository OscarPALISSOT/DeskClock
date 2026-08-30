//
//  AuthenticationService.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 25/06/2026.
//

import AuthenticationServices
import UIKit

@Observable
class AuthService: NSObject {
    var isAuthenticated = false
    var currentUser: User?
    
    override init() {
        let token = try? KeychainService.read(.accessToken)
        isAuthenticated = token != nil
        super.init()
        DebugLoggerService.shared.log(isAuthenticated ? "Token found at launch" : "No token found at launch")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthExpired),
            name: .authDidExpire,
            object: nil
        )
        
        if isAuthenticated {
            Task { await fetchCurrentUser() }
        }
    }
    
    func login(email: String, password: String) async throws {
        let dto = try await APIClient.shared.login(email: email, password: password)
        try KeychainService.save(dto.access_token, for: .accessToken)
        try KeychainService.save(dto.refresh_token, for: .refreshToken)
        isAuthenticated = true
        await fetchCurrentUser()
    }
    
    func register(email: String, password: String) async throws {
        let dto = try await APIClient.shared.register(email: email, password: password)
        try KeychainService.save(dto.access_token, for: .accessToken)
        try KeychainService.save(dto.refresh_token, for: .refreshToken)
        isAuthenticated = true
        await fetchCurrentUser()
    }
    
    func logout() {
        try? KeychainService.delete(.accessToken)
        try? KeychainService.delete(.refreshToken)
        isAuthenticated = false
        currentUser = nil
    }
    
    @objc private func handleAuthExpired() {
        DebugLoggerService.shared.log("Forced deconnexion, refresh failed")
        isAuthenticated = false
        currentUser = nil
    }
    
    private func fetchCurrentUser() async {
        do {
            currentUser = try await APIClient.shared.getMe()
        } catch {
            DebugLoggerService.shared.log("Failed to fetch user profile: \(error)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // for sign in with apple, to updated
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

// for sign in with apple, to updated
extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            print("Invalid credential or missing identity token")
            return
        }
        
        print("Identity token:", tokenString)
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("Sign in error:", error)
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first
        else {
            fatalError("Active window not found")
        }
        return window
    }
}
