//
//  LinkedInSearchFormView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct LinkedInSearchFormView: View {
    @Environment(\.dismiss) var dismiss
    // Common LinkedIn search parameters - update these based on your n8n form
    @State private var searchQuery: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var position: String = ""
    @State private var locations: String = ""
    @State private var industries: String = ""
    @State private var currentCompanies: String = ""
    @State private var previousCompanies: String = ""
    @State private var schools: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search Parameters")) {
                    TextField("Search Query / Keywords", text: $searchQuery)
                        .textContentType(.none)
                    
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    
                    TextField("Position / Job Title", text: $position)
                        .textContentType(.jobTitle)
                    
                    TextField("Locations (comma-separated)", text: $locations)
                        .textContentType(.addressCity)
                    
                    TextField("Industries (comma-separated)", text: $industries)
                    
                    TextField("Current Companies (comma-separated)", text: $currentCompanies)
                        .textContentType(.organizationName)
                    
                    TextField("Previous Companies (comma-separated)", text: $previousCompanies)
                        .textContentType(.organizationName)
                    
                    TextField("Schools (comma-separated)", text: $schools)
                }
                
                Section(header: Text("Instructions")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fill out the parameters above to search for LinkedIn profiles.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• Search Query: Main search term or keywords")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Multiple values: Use commas to separate multiple entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Leave fields empty if not needed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\nNote: Update this form to match your n8n form fields.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("LinkedIn Search Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitSearch()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func submitSearch() {
        // Here you would typically send the parameters to your backend/n8n workflow
        // For now, we'll just show the parameters and dismiss
        print("LinkedIn Search Parameters:")
        print("Search Query: \(searchQuery)")
        print("First Name: \(firstName)")
        print("Last Name: \(lastName)")
        print("Position: \(position)")
        print("Locations: \(locations)")
        print("Industries: \(industries)")
        print("Current Companies: \(currentCompanies)")
        print("Previous Companies: \(previousCompanies)")
        print("Schools: \(schools)")
        
        // TODO: Send to n8n workflow or backend API
        // You can make an HTTP POST request to your n8n webhook endpoint here
        dismiss()
    }
}

#Preview {
    LinkedInSearchFormView()
}

