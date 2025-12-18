//
//  ResumePreviewView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import PDFKit
import QuickLook

struct ResumePreviewView: View {
    let fileURL: URL
    let fileName: String
    
    @State private var showQuickLook = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Document Preview
            if fileURL.pathExtension.lowercased() == "pdf" {
                PDFPreviewView(url: fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // For Word documents, use QuickLook
                QuickLookPreview(selectedFile: fileURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Resume Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showQuickLook = true
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showQuickLook) {
            QuickLookPreview(selectedFile: fileURL)
        }
    }
    
    private var fileIcon: String {
        let ext = fileURL.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
}

struct PDFPreviewView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // No updates needed
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let selectedFile: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: QuickLookPreview
        
        init(_ parent: QuickLookPreview) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.selectedFile as QLPreviewItem
        }
    }
}

#Preview {
    NavigationView {
        ResumePreviewView(
            fileURL: URL(fileURLWithPath: "/path/to/resume.pdf"),
            fileName: "resume.pdf"
        )
    }
}

