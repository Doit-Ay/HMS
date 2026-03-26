//
//  PatientPrescriptionsView.swift
//  HMS
//
//  Created on 20/03/26.
//

import SwiftUI
import PDFKit

// MARK: - Patient Prescriptions View
struct PatientPrescriptionsView: View {
    
    @State private var prescriptions: [PrescriptionDocument] = []
    @State private var isLoading = true
    @State private var animate = false
    @ObservedObject var session = UserSession.shared
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AppTheme.primary)
            } else if prescriptions.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryMid.opacity(0.08))
                            .frame(width: 100, height: 100)
                        Image(systemName: "pills.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(AppTheme.primaryMid.opacity(0.5))
                    }
                    
                    Text("No Prescriptions Yet")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Prescriptions from your doctors\nwill appear here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(Array(prescriptions.enumerated()), id: \.element.id) { index, doc in
                            let title = doc.customName ?? "Prescription - \(doc.date)"
                            NavigationLink(destination: PatientPrescriptionPDFView(prescription: doc)) {
                                PatientPrescriptionCard(
                                    doctorName: doc.doctorName,
                                    date: doc.date,
                                    time: doc.startTime,
                                    type: "Prescription",
                                    icon: "doc.text.fill",
                                    color: AppTheme.primary,
                                    customTitle: doc.customName
                                )
                            }
                            .buttonStyle(.plain)
                            .offset(y: animate ? 0 : 20)
                            .opacity(animate ? 1 : 0)
                            .animation(.spring().delay(Double(index) * 0.05), value: animate)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Doctor Prescriptions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPrescriptions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { animate = true }
            }
        }
        .refreshable { await fetchPrescriptions() }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func fetchPrescriptions() async {
        guard let patientId = session.currentUser?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let docs = try await DoctorPatientRepository.shared.fetchPatientPrescriptions(patientId: patientId)
            
            await MainActor.run {
                self.prescriptions = docs
                self.isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Prescription Card
struct PatientPrescriptionCard: View {
    let doctorName: String
    let date: String
    let time: String
    let type: String
    let icon: String
    let color: Color
    let customTitle: String?
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let title = customTitle {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text("Dr. \(doctorName)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                } else {
                    Text("Dr. \(doctorName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(date)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppTheme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(time)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(type)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - PDF Viewer for Prescriptions (with caching + loader)
struct PatientPrescriptionPDFView: View {
    @State var prescription: PrescriptionDocument
    
    @State private var pdfDocument: PDFDocument? = nil
    @State private var localFileURL: URL? = nil
    @State private var shareURL: URL? = nil
    @State private var isLoading = true
    @State private var loadFailed = false
    
    // Rename state
    @State private var showRenameAlert = false
    @State private var newName = ""
    
    private var displayTitle: String {
        prescription.customName ?? "Prescription - \(prescription.date)"
    }
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            if isLoading {
                // iOS-style loader while PDF loads
                VStack(spacing: 18) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    
                    Text("Loading Prescription…")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            } else if loadFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Unable to load prescription")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Button {
                        Task { await loadPDF() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.primary)
                        .cornerRadius(10)
                    }
                }
            } else if let pdfDocument {
                CachedPDFKitView(document: pdfDocument)
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        newName = displayTitle
                        showRenameAlert = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    if let url = shareURL {
                        ShareLink(item: url) {
                            Label("Download / Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .alert("Rename Prescription", isPresented: $showRenameAlert) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task { await renamePrescription() }
            }
        }
        .task { await loadPDF() }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func updateShareURL(from localURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = displayTitle.replacingOccurrences(of: "/", with: "-")
        let finalName = safeName.lowercased().hasSuffix(".pdf") ? safeName : "\(safeName).pdf"
        let newURL = tempDir.appendingPathComponent(finalName)
        
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                try FileManager.default.removeItem(at: newURL)
            }
            try FileManager.default.copyItem(at: localURL, to: newURL)
            self.shareURL = newURL
        } catch {
            #if DEBUG
            print("❌ Failed to create shareable file:", error)
            #endif
            self.shareURL = localURL
        }
    }
    
    private func renamePrescription() async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        var updatedDoc = prescription
        updatedDoc.customName = newName.trimmingCharacters(in: .whitespaces)
        
        do {
            try await DoctorPatientRepository.shared.savePrescriptionDocument(updatedDoc)
            await MainActor.run {
                self.prescription = updatedDoc
            }
        } catch {
            #if DEBUG
            print("Failed to rename prescription: \(error)")
            #endif
        }
    }
    
    private func loadPDF() async {
        guard let remoteURL = URL(string: prescription.pdfUrl) else {
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            loadFailed = false
        }
        
        let cache = PDFCacheManager.shared
        
        // 1) Try to load from cache first (instant)
        if let cachedURL = cache.cachedFileURL(for: remoteURL),
           let doc = PDFDocument(url: cachedURL) {
            await MainActor.run {
                self.pdfDocument = doc
                self.localFileURL = cachedURL
                self.updateShareURL(from: cachedURL)
                self.isLoading = false
            }
            
            // 2) Background refresh — check for updates silently
            let didUpdate = await cache.refreshIfNeeded(from: remoteURL)
            if didUpdate,
               let updatedURL = cache.cachedFileURL(for: remoteURL),
               let updatedDoc = PDFDocument(url: updatedURL) {
                await MainActor.run {
                    self.pdfDocument = updatedDoc
                }
            }
            return
        }
        
        // 3) No cache — download fresh
        if let localURL = await cache.download(from: remoteURL),
           let doc = PDFDocument(url: localURL) {
            await MainActor.run {
                self.pdfDocument = doc
                self.localFileURL = localURL
                self.updateShareURL(from: localURL)
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.loadFailed = true
                self.isLoading = false
            }
        }
    }
}

// MARK: - PDFKit wrapper that takes a PDFDocument directly
struct CachedPDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = document
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
    }
}


