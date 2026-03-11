import SwiftUI

struct DoctorAvailabilityView: View {
    @State private var appearAnimation = false
    
    // Calendar State
    @State private var selectedDate: Date? = Date()
    @State private var availabilityMap: [Date: DayAvailabilityState] = [:] // Real map of data
    
    // Bottom Panel State
    @State private var markAsSelection: DayAvailabilityState = .available
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600)
    
    // Toast & Alert State
    @State private var showToast = false
    @State private var showConflictAlert = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // 1. Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("My Availability")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // Empty spacer to balance the massive chevron icon
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .offset(y: appearAnimation ? 0 : -20)
                .opacity(appearAnimation ? 1 : 0)
                
                // Scrollable Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 2. Calendar
                        AvailabilityCalendarView(
                            selectedDate: $selectedDate,
                            availabilityMap: availabilityMap
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .offset(y: appearAnimation ? 0 : 20)
                        // Trigger bottom panel update when selected date changes
                        .onChange(of: selectedDate) { newDate in
                            if let date = newDate {
                                let startOfDay = Calendar.current.startOfDay(for: date)
                                // Sync the toggle with whatever state this date intrinsically holds
                                markAsSelection = availabilityMap[startOfDay] ?? .available
                            }
                        }
                        
                        // Only show options if a valid date is selected
                        if selectedDate != nil {
                            // Bottom Options Container
                            VStack(alignment: .leading, spacing: 24) {
                                
                                // 3. Mark As Toggle
                                MarkAsToggleView(selection: $markAsSelection)
                                
                                // 4. Time Picker (Slide down if half day)
                                if markAsSelection == .halfDay {
                                    TimeRangePickerView(
                                        startTime: $startTime,
                                        endTime: $endTime
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 100) // Space for floating Save button
                        } else {
                            // Blank state when no date is picked
                            VStack(spacing: 12) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                Text("Select a date to manage availability")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                }
            } // End of Main VStack
            .opacity(appearAnimation ? 1 : 0)
            
            // 5. Bottom Save CTA
            if selectedDate != nil {
                VStack(spacing: 8) {
                    // Error hint text
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    }
                    
                    Button(action: handleSaveRequest) {
                        Text("Save Changes")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .cornerRadius(16)
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                // Add tiny white gradient behind button so it doesn't overlap text when scrolling
                .background(
                    LinearGradient(colors: [AppTheme.background.opacity(0), AppTheme.background, AppTheme.background], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 6. Success Toast
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Availability updated")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
            // Seed fake data to prove UI
            let today = Calendar.current.startOfDay(for: Date())
            availabilityMap[today.addingTimeInterval(86400 * 3)] = .halfDay
        }
        // Conflict Alert Modal
        .alert(isPresented: $showConflictAlert) {
            Alert(
                title: Text("Conflict Detected"),
                message: Text("You have 2 appointments on this day. Marking unavailable will notify patients."),
                primaryButton: .destructive(Text("Mark Anyway")) { executeSave() },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Safety check flow
    private func handleSaveRequest() {
        guard let date = selectedDate else {
            withAnimation { errorMessage = "Please select a date first" }
            return
        }
        errorMessage = nil
        
        // Simulating a conflict check (Random 1-in-5 chance to pop conflict alert just for UX demo)
        let isSimulatedConflict = arc4random_uniform(5) == 0 && markAsSelection != .available
        
        if isSimulatedConflict {
            showConflictAlert = true
        } else {
            executeSave()
        }
    }
    
    // Final commit flow
    private func executeSave() {
        if let date = selectedDate {
            let startOfDay = Calendar.current.startOfDay(for: date)
            availabilityMap[startOfDay] = markAsSelection
            
            // Trigger toast
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showToast = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showToast = false
                }
            }
        }
    }
}

#Preview {
    DoctorAvailabilityView()
}
