//
//  PatientLabRequestsView.swift
//  HMS
//
//  Created by admin73 on 18/03/26.
//

import SwiftUI
import FirebaseFirestore

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
                        Image(systemName: "flask")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("No lab test requests")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Your doctor hasn't requested any lab tests yet")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(labRequests) { request in
                                LabRequestStatusCard(request: request)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Lab Test Results")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchLabRequests()
        }
    }
    
    private func fetchLabRequests() {
        guard let patientId = session.currentUser?.id else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("patient_lab_requests")
            .whereField("patientId", isEqualTo: patientId)
            .order(by: "dateRequested", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    print("Error fetching lab requests: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                labRequests = documents.compactMap { doc -> PatientLabRequest? in
                    let data = doc.data()
                    
                    guard let patientId = data["patientId"] as? String,
                          let patientName = data["patientName"] as? String,
                          let testsData = data["tests"] as? [[String: Any]],
                          let timestamp = data["dateRequested"] as? Timestamp else {
                        return nil
                    }
                    
                    var tests: [RequestedTest] = []
                    
                    for testData in testsData {
                        if let name = testData["name"] as? String,
                           let price = testData["price"] as? Int {
                            
                            let requestedByDoctor = testData["requestedByDoctor"] as? String
                            let resultURL = testData["resultURL"] as? String
                            let resultFileName = testData["resultFileName"] as? String
                            let completedDate = (testData["completedDate"] as? Timestamp)?.dateValue()
                            
                            let test = RequestedTest(
                                name: name,
                                price: price,
                                requestedByDoctor: requestedByDoctor,
                                resultURL: resultURL,
                                resultFileName: resultFileName,
                                completedDate: completedDate
                            )
                            tests.append(test)
                        }
                    }
                    
                    return PatientLabRequest(
                        id: doc.documentID,
                        patientId: patientId,
                        patientName: patientName,
                        tests: tests,
                        dateRequested: timestamp.dateValue(),
                        status: data["status"] as? String ?? "pending"
                    )
                }
            }
    }
}

// MARK: - Models
struct PatientLabRequest: Identifiable {
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
}

struct RequestedTest: Identifiable {
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
}

// MARK: - Status Card
struct LabRequestStatusCard: View {
    
    let request: PatientLabRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requested on \(request.dateRequested.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    HStack {
                        Text("\(request.completedTestsCount)/\(request.totalTestsCount) tests completed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(request.allCompleted ? .green : .orange)
                        
                        Spacer()
                        
                        // Status Badge
                        Text(request.allCompleted ? "Completed" : "In Progress")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(request.allCompleted ? .green : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                (request.allCompleted ? Color.green : Color.orange)
                                    .opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                }
            }
            
            Divider()
            
            // Tests List
            ForEach(request.tests) { test in
                TestResultRow(test: test)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct TestResultRow: View {
    
    let test: RequestedTest
    @State private var showPDFViewer = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(test.isCompleted ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                
                if test.isCompleted {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }
            
            // Test Info
            VStack(alignment: .leading, spacing: 4) {
                Text(test.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                
                if let doctor = test.requestedByDoctor, !doctor.isEmpty {
                    Text("Requested by Dr. \(doctor)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.primary)
                }
                
                if let completedDate = test.completedDate {
                    Text("Completed: \(completedDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // View Result Button (if completed)
            if test.isCompleted {
                Button {
                    showPDFViewer = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                        Text("View")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary)
                    .cornerRadius(8)
                }
                .sheet(isPresented: $showPDFViewer) {
                    if let urlString = test.resultURL, let url = URL(string: urlString) {
                        NavigationStack {
                            PatientPDFKitView(url: url)
                                .navigationTitle(test.name)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        Button("Done") {
                                            showPDFViewer = false
                                        }
                                    }
                                }
                        }
                    }
                }
            } else {
                // Pending indicator
                Text("Pending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}
