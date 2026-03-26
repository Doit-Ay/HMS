import SwiftUI
import FirebaseFirestore

struct LabTestsView: View {
    
    // MARK: - Doctor Lab Request Model
    struct DoctorLabRequest: Identifiable {
        let id: String
        let doctorId: String
        let doctorName: String
        let patientId: String
        let patientName: String
        let testNames: [String]
        let dateReferred: Date
    }
    
    @State private var searchText = ""
    @State private var labTests: [LabTest] = []
    @State private var requestedTests: [DoctorLabRequest] = []
    @State private var isLoading = true
    @State private var selectedSegment = 0 // 0 = All, 1 = Requested
    @StateObject private var cartManager = LabCartManager.shared
    
    var filteredAllTests: [LabTest] {
        if searchText.isEmpty { return labTests }
        return labTests.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var filteredRequestedTests: [DoctorLabRequest] {
        if searchText.isEmpty { return requestedTests }
        return requestedTests.filter { request in
            request.testNames.contains { testName in
                testName.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Search Bar
                HMSSearchBar(
                    placeholder: selectedSegment == 0 ? "Search lab tests..." : "Search requested tests...",
                    text: $searchText
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Segmented Control
                Picker("Test Type", selection: $selectedSegment) {
                    Text("All Tests").tag(0)
                    Text("Requested Tests").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(AppTheme.primary)
                    Spacer()
                    
                } else if selectedSegment == 0 {
                    // All Tests Section
                    if labTests.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "flask")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("No lab tests available")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Please check back later")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredAllTests) { test in
                                    LabTestCard(
                                        test: test,
                                        showBookButton: true,
                                        isInCart: cartManager.cartItems.contains(where: { $0.id == test.id }),
                                        onAddToCart: {
                                            cartManager.addToCart(test)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    
                } else {
                    // Requested Tests Section
                    if requestedTests.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("No requested tests")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Your doctor hasn't requested any tests yet")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRequestedTests) { request in
                                    // In the Requested Tests Section, update the ForEach:
                                    ForEach(filteredRequestedTests) { request in
                                        ForEach(request.testNames, id: \.self) { testName in
                                            RequestedTestCard(
                                                testName: testName,
                                                doctorName: request.doctorName,
                                                dateReferred: request.dateReferred,
                                                requestId: request.id,  // Pass the request ID
                                                onAddToCart: {
                                                    cartManager.addRequestedTestToCart(
                                                        testName: testName,
                                                        price: 599,
                                                        doctorName: request.doctorName
                                                    )
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
        }
        .navigationTitle("Lab Tests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    cartManager.showCart = true
                } label: {
                    ZStack {
                        Image(systemName: "cart")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.primary)
                        
                        if cartManager.totalItems > 0 {
                            Text("\(cartManager.totalItems)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 10, y: -10)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $cartManager.showCart) {
            CartView()
        }
        .onAppear {
            fetchLabTests()
            fetchRequestedTests()
        }
    }
    
    private func fetchLabTests() {
        let db = Firestore.firestore()
        
        db.collection("labTests").getDocuments { snapshot, error in
            if let error = error {
                #if DEBUG
                print("Error fetching lab tests: \(error)")
                #endif
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            labTests = documents.compactMap { doc -> LabTest? in
                try? doc.data(as: LabTest.self)
            }
        }
    }
    
    private func fetchRequestedTests() {
        guard let patientId = UserSession.shared.currentUser?.id else {
            #if DEBUG
            print("No patient ID found")
            #endif
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        // 1) First, fetch all checked-out test names from patient_lab_requests
        db.collection("patient_lab_requests")
            .whereField("patientId", isEqualTo: patientId)
            .getDocuments { plrSnapshot, plrError in
                
                // Build a set of test names that have already been checked out
                var checkedOutTestNames: Set<String> = []
                if let plrDocs = plrSnapshot?.documents {
                    for doc in plrDocs {
                        let data = doc.data()
                        if let tests = data["tests"] as? [[String: Any]] {
                            for test in tests {
                                if let name = test["name"] as? String {
                                    checkedOutTestNames.insert(name)
                                }
                            }
                        }
                    }
                }
                
                // 2) Now fetch doctor-referred requests and filter out checked-out ones
                db.collection("lab_test_requests")
                    .whereField("patientId", isEqualTo: patientId)
                    .getDocuments { snapshot, error in
                        
                        self.isLoading = false
                        
                        if let error = error {
                            #if DEBUG
                            print("Error fetching requested tests: \(error)")
                            #endif
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            self.requestedTests = []
                            return
                        }
                        
                        var tests: [DoctorLabRequest] = []
                        
                        for doc in documents {
                            let data = doc.data()
                            
                            guard let doctorId = data["doctorId"] as? String,
                                  let doctorName = data["doctorName"] as? String,
                                  let patientId = data["patientId"] as? String,
                                  let patientName = data["patientName"] as? String,
                                  let testNames = data["testNames"] as? [String],
                                  let timestamp = data["dateReferred"] as? Timestamp else {
                                continue
                            }
                            
                            // Filter out test names that have already been checked out
                            let remainingTests = testNames.filter { !checkedOutTestNames.contains($0) }
                            
                            // Only include this request if it still has unchecked-out tests
                            guard !remainingTests.isEmpty else { continue }
                            
                            let request = DoctorLabRequest(
                                id: doc.documentID,
                                doctorId: doctorId,
                                doctorName: doctorName,
                                patientId: patientId,
                                patientName: patientName,
                                testNames: remainingTests,
                                dateReferred: timestamp.dateValue()
                            )
                            tests.append(request)
                        }
                        
                        self.requestedTests = tests.sorted { $0.dateReferred > $1.dateReferred }
                    }
            }
    }
}

// MARK: - Updated Lab Test Card
struct LabTestCard: View {
    
    let test: LabTest
    let showBookButton: Bool
    let isInCart: Bool
    let onAddToCart: () -> Void
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(test.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "flask.fill")
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 22))
            }
            
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
                Text(test.preparation)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("₹\(test.price)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Reports in \(test.reportTime)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                if showBookButton {
                    Button(action: onAddToCart) {
                        HStack {
                            Image(systemName: isInCart ? "checkmark.circle.fill" : "cart.badge.plus")
                            Text(isInCart ? "Added" : "Add to Cart")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(isInCart ? .green : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isInCart ? Color.green.opacity(0.1) : AppTheme.primary)
                        .cornerRadius(10)
                    }
                    .disabled(isInCart)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Updated Requested Test Card
struct RequestedTestCard: View {
    
    let testName: String
    let doctorName: String
    let dateReferred: Date
    let requestId: String  // Add this parameter to pass the request ID
    let onAddToCart: () -> Void
    
    @ObservedObject var cartManager = LabCartManager.shared
    
    // Computed property to check if this specific test is in cart
    private var isInCart: Bool {
        cartManager.cartItems.contains { item in
            // Check if this is a requested test with matching name and doctor
            item.name == testName && item.requestedByDoctor == doctorName
        }
    }
    
    // Generate a consistent ID for this test
    private var cartItemId: String {
        "\(requestId)_\(testName)"
    }
    
    private var sampleTest: LabTest {
        LabTest(
            name: testName,
            price: 599,
            description: "Test requested by your doctor",
            category: "Requested Test",
            preparation: "As advised by doctor",
            reportTime: "24-48 hours"
        )
    }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            // Doctor Info
            HStack {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "stethoscope")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dr. \(doctorName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Requested on \(dateReferred.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Test Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(testName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(sampleTest.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "flask.fill")
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 22))
            }
            
//            HStack {
//                Image(systemName: "clock")
//                    .font(.system(size: 10))
//                    .foregroundColor(AppTheme.textSecondary)
//                Text(sampleTest.preparation)
//                    .font(.system(size: 11))
//                    .foregroundColor(AppTheme.textSecondary)
//            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("₹\(sampleTest.price)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Reports in \(sampleTest.reportTime)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    if !isInCart {
                        onAddToCart()
                    }
                }) {
                    HStack {
                        Image(systemName: isInCart ? "checkmark.circle.fill" : "cart.badge.plus")
                        Text(isInCart ? "Added" : "Add to Cart")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(isInCart ? .green : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isInCart ? Color.green.opacity(0.1) : AppTheme.primary)
                    .cornerRadius(10)
                }
                .disabled(isInCart)
            }
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
