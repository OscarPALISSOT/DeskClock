//
//  LoginView.swift
//  DeskClock
//
//  Created by Oscar PALISSOT on 25/06/2026.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App name
            VStack(spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundStyle(.primary)
                Text("DeskClock")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("Badgeuse automatique")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Form
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            topTrailingRadius: 12
                        ))
                    
                    Divider()
                    
                    SecureField("Mot de passe", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(UnevenRoundedRectangle(
                            bottomLeadingRadius: 12,
                            bottomTrailingRadius: 12
                        ))
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                
                Button {
                    Task { await handleLogin() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Se connecter")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
                
                Button {
                    Task { await handleRegister() }
                } label: {
                    Text("Créer un compte")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 48)
        }
        .onTapGesture { hideKeyboard() }
    }
    
    private func handleLogin() async {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = "Email ou mot de passe incorrect"
        }
        isLoading = false
    }
    
    private func handleRegister() async {
        guard validate() else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.register(email: email, password: password)
        } catch {
            errorMessage = "Impossible de créer le compte"
        }
        isLoading = false
    }
    
    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Remplis tous les champs"
            return false
        }
        return true
    }
}
