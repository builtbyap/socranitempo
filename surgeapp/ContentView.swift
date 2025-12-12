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
            JobSearchView()
                .tabItem {
                    Label("Jobs", systemImage: "briefcase")
                }
            
            LinkedInSearchView()
                .tabItem {
                    Label("LinkedIn", systemImage: "person.2")
                }
            
            EmailSearchView()
                .tabItem {
                    Label("Emails", systemImage: "envelope")
                }
        }
    }
}

#Preview {
    ContentView()
}
