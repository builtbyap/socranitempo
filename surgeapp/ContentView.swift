//
//  ContentView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper.fill")
                }
            
            ApplicationsView()
                .tabItem {
                    Label("Applications", systemImage: "briefcase.fill")
                }
            
            LinkedInSearchView()
                .tabItem {
                    Label("LinkedIn", systemImage: "person.2")
                }
            
            EmailSearchView()
                .tabItem {
                    Label("Emails", systemImage: "envelope")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
