//
//  PatientLabRequestsView.swift
//  HMS
//
//  Created by admin73 on 18/03/26.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Patient Lab Requests View (List of Requests)
struct PatientLabRequestsView: View {
    
    @State private var labRequests: [PatientLabRequest] = []
    @State private var isLoading = true
    @ObservedObject var session = UserSession.shared
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Spacer()
                } else if labRequests.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.08))
                                .frame(width: 100, height: 100)
                            Image(systemName: "flask")
                                .font(.system(size: 44))
                                .foregroundColor(AppTheme.primary.opacity(0.5))
                        }
                        
                        Text("No Lab Test Requests")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Your lab test requests will appear here\nonce you or your doctor submits one.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(labRequests) { request in
                                LabReportCard(request: request)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("Lab Reports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await fetchLabRequests() }
        }
    }
    
    private func fetchLabRequests() async {
        guard let patientId = session.currentUser?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let db = Firestore.firestore()
        var allRequests: [PatientLabRequest] = []
        
        // 0) Fetch price lookup from labTests collection
        var priceLookup: [String: Int] = [:]
        do {
            let labTestsSnapshot = try await db.collection("labTests").getDocuments()
            for doc in labTestsSnapshot.documents {
                let data = doc.data()
                if let name = data["name"] as? String {
                    if let price = data["price"] as? Int {
                        priceLookup[name] = price
                    } else if let price = data["price"] as? Double {
                        priceLookup[name] = Int(price)
                    }
                }
            }
        } catch {}
        
        // 1) Fetch from patient_lab_requests (created via cart checkout)
        do {
            let snapshot = try await db.collection("patient_lab_requests")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                guard let pId = data["patientId"] as? String,
                      let pName = data["patientName"] as? String,
                      let testsData = data["tests"] as? [[String: Any]],
                      let timestamp = data["dateRequested"] as? Timestamp else {
                    continue
                }
                
                var tests: [RequestedTest] = []
                for testData in testsData {
                    if let name = testData["name"] as? String {
                        // Try stored price first, then lookup, then 0
                        var price = 0
                        if let p = testData["price"] as? Int {
                            price = p
                        } else if let p = testData["price"] as? Double {
                            price = Int(p)
                        } else {
                            price = priceLookup[name] ?? 0
                        }
                        
                        tests.append(RequestedTest(
                            name: name,
                            price: price,
                            requestedByDoctor: testData["requestedByDoctor"] as? String,
                            resultURL: testData["resultURL"] as? String,
                            resultFileName: testData["resultFileName"] as? String,
                            completedDate: (testData["completedDate"] as? Timestamp)?.dateValue()
                        ))
                    }
                }
                
                allRequests.append(PatientLabRequest(
                    id: doc.documentID,
                    patientId: pId,
                    patientName: pName,
                    tests: tests,
                    dateRequested: timestamp.dateValue(),
                    status: data["status"] as? String ?? "pending"
                ))
            }
        } catch {
            
        }
        
        // 2) Fetch from lab_test_requests (created via doctor referral)
        do {
            let snapshot = try await db.collection("lab_test_requests")
                .whereField("patientId", isEqualTo: patientId)
                .getDocuments()
            
            for doc in snapshot.documents {
                let data = doc.data()
                let testNames = data["testNames"] as? [String] ?? []
                
                guard let pId = data["patientId"] as? String,
                      let pName = data["patientName"] as? String,
                      !testNames.isEmpty,
                      let timestamp = data["dateReferred"] as? Timestamp else {
                    continue
                }
                
                let doctorName = data["doctorName"] as? String
                
                let tests = testNames.map { name in
                    RequestedTest(
                        name: name,
                        price: priceLookup[name] ?? 0,
                        requestedByDoctor: doctorName,
                        resultURL: nil,
                        resultFileName: nil,
                        completedDate: nil
                    )
                }
                
                allRequests.append(PatientLabRequest(
                    id: doc.documentID,
                    patientId: pId,
                    patientName: pName,
                    tests: tests,
                    dateRequested: timestamp.dateValue(),
                    status: data["status"] as? String ?? "pending"
                ))
            }
        } catch {
            
        }
        
        // 3) Sort and update UI
        let sorted = allRequests.sorted { $0.dateRequested > $1.dateRequested }
        
        await MainActor.run {
            self.labRequests = sorted
            self.isLoading = false
        }
    }
}

// MARK: - Models
struct PatientLabRequest: Identifiable, Hashable {
    let id: String
    let patientId: String
    let patientName: String
    let tests: [RequestedTest]
    let dateRequested: Date
    let status: String
    
    var completedTestsCount: Int {
        tests.filter { $0.isCompleted }.count
    }
    
    var totalTestsCount: Int {
        tests.count
    }
    
    var allCompleted: Bool {
        completedTestsCount == totalTestsCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PatientLabRequest, rhs: PatientLabRequest) -> Bool {
        lhs.id == rhs.id
    }
}

struct RequestedTest: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let price: Int
    let requestedByDoctor: String?
    let resultURL: String?
    let resultFileName: String?
    let completedDate: Date?
    
    var isCompleted: Bool {
        resultURL != nil && !resultURL!.isEmpty
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RequestedTest, rhs: RequestedTest) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Lab Report Card (inline card matching screenshot)
struct LabReportCard: View {
    
    let request: PatientLabRequest
    @State private var selectedReportURL: URL? = nil
    @State private var showPDF = false
    
    private var isCompleted: Bool { request.allCompleted }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            // HEADER — Date + Status Badge
            HStack {
                Text(request.dateRequested.formatted(date: .long, time: .omitted))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Text(isCompleted ? "Completed" : "Pending")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isCompleted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(isCompleted ? .green : .orange)
                    .cornerRadius(8)
            }
            
            Divider()
            
            // TESTS
            ForEach(request.tests) { test in
                
                VStack(alignment: .leading, spacing: 10) {
                    
                    HStack {
                        Text(test.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Text("₹\(test.price)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    if let date = test.completedDate {
                        Text(date.formatted(date: .long, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    // View Report button
                    if isCompleted,
                       let urlString = test.resultURL,
                       !urlString.isEmpty,
                       let url = URL(string: urlString) {
                        
                        Button {
                            selectedReportURL = url
                            showPDF = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 13))
                                Text("View Report")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.primary)
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showPDF) {
            if let url = selectedReportURL {
                NavigationStack {
                    PatientPDFKitView(url: url)
                        .navigationTitle("Lab Report")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showPDF = false }
                            }
                        }
                }
            }
        }
    }
}
