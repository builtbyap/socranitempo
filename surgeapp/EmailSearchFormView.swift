//
//  EmailSearchFormView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct EmailSearchFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var company: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var foundEmail: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Email Search Parameters")) {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                    
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }
                
                Section(header: Text("Instructions")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fill out the parameters above to search for an employee's email address.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• Company: The company name (e.g., 'Apple Inc')")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• First Name: Employee's first name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Last Name: Employee's last name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• The system will automatically generate the company domain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let email = foundEmail {
                    Section(header: Text("Found Email")) {
                        Text(email)
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Email Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Search") {
                        Task {
                            await submitSearch()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting || !isFormValid)
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching for email...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let email = foundEmail {
                    Text("Email found and saved: \(email)")
                } else {
                    Text("Email search completed!")
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !company.isEmpty && !firstName.isEmpty && !lastName.isEmpty
    }
    
    private func submitSearch() async {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        foundEmail = nil
        
        do {
            // Step 1: Find email using Hunter.io
            let result = try await HunterService.shared.findEmail(
                company: company,
                firstName: firstName,
                lastName: lastName
            )
            
            await MainActor.run {
                foundEmail = result.email
            }
            
            if result.found, let email = result.email {
                // Step 2: Save to Supabase
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let emailContact = EmailContact(
                    id: UUID().uuidString,
                    name: result.fullName,
                    email: email,
                    company: company,
                    lastContact: formatter.string(from: Date())
                )
                
                try await SupabaseService.shared.insertEmailContact(emailContact)
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } else {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "No email found for this person at this company."
                }
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    EmailSearchFormView()
}

