import SwiftUI

struct DoctorProfileView: View {
    @State private var isEditing = false
    @State private var showSaveToast = false
    @State private var appearAnimation = false
    
    // Fake Doctor Identity for demo purposes
    @State private var profileImage = "Dr. S" // Placeholder for an actual Image string
    
    // State arrays for the dynamic form
    @State private var personalFields = [
        ProfileInfoField(title: "Full Name", value: "Dr. Saif Ababon"),
        ProfileInfoField(title: "Date of Birth", value: "12 May 1985"),
        ProfileInfoField(title: "Gender", value: "Male", options: ["Male", "Female", "Other"])
    ]
    
    @State private var professionalFields = [
        ProfileInfoField(title: "Specialty", value: "Cardiologist", options: ["Cardiologist", "Neurologist", "Pediatrician"]),
        ProfileInfoField(title: "Doctor ID", value: "ID: 32145687", isEditable: false),
        ProfileInfoField(title: "Years of Experience", value: "12 Years", keyboardType: .numberPad)
    ]
    
    @State private var contactFields = [
        ProfileInfoField(title: "Phone Number", value: "+1 234 567 8900", keyboardType: .phonePad),
        ProfileInfoField(title: "Email Address", value: "saif.ababon@hospital.com", keyboardType: .emailAddress)
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // 1. Hero Section
                    ZStack(alignment: .bottom) {
                        // Mint Gradient + Wave Base
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 180)
                        
                        // Fake Sine Wave
                        Path { path in
                            let width = UIScreen.main.bounds.width
                            let height: CGFloat = 40
                            path.move(to: CGPoint(x: 0, y: height))
                            path.addCurve(to: CGPoint(x: width, y: height), control1: CGPoint(x: width * 0.25, y: 0), control2: CGPoint(x: width * 0.75, y: height * 2))
                            path.addLine(to: CGPoint(x: width, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: 0))
                        }
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 40)
                        .offset(y: -40) // Place near bottom of gradient
                        
                        // Top Nav Buttons
                        VStack {
                            HStack {
                                Button(action: { /* back logic if needed */ }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                }
                                
                                Spacer()
                                
                                Button(action: toggleEditMode) {
                                    if isEditing {
                                        Text("Save")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(AppTheme.primary)
                                            .clipShape(Capsule())
                                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                                    } else {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.white)
                                            .clipShape(Circle())
                                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            Spacer()
                        }
                        
                        // Overlapping Avatar + Title
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 110, height: 110)
                                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
                                    .overlay(
                                        Text(profileImage)
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.primaryDark)
                                    )
                                
                                if isEditing {
                                    Circle()
                                        .fill(AppTheme.primary)
                                        .frame(width: 32, height: 32)
                                        .overlay(Image(systemName: "camera.fill").font(.system(size: 14)).foregroundColor(.white))
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .offset(x: -4, y: -4)
                                        .transition(.scale)
                                }
                            }
                            .offset(y: 55) // Halfway out of the gradient box
                        }
                    }
                    .ignoresSafeArea(edges: .top) // let gradient reach top of screen
                    
                    VStack(spacing: 4) {
                        Text("Cardiologist")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("Dr. Saif Ababon")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("ID: 32145687")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                    }
                    .padding(.top, 65) // Space for overlapping avatar
                    .offset(y: appearAnimation ? 0 : 20)
                    .opacity(appearAnimation ? 1 : 0)
                    
                    // 2. Stats Bar
                    DoctorStatsBar()
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .offset(y: appearAnimation ? 0 : 30)
                        .opacity(appearAnimation ? 1 : 0)
                    
                    // 3. Info Cards & Sign Out
                    VStack(spacing: 20) {
                        ProfileInfoCard(title: "Personal", fields: $personalFields, isEditing: isEditing)
                        ProfileInfoCard(title: "Professional", fields: $professionalFields, isEditing: isEditing)
                        ProfileInfoCard(title: "Contact", fields: $contactFields, isEditing: isEditing)
                        
                        // Sign Out Button
                        if !isEditing {
                            Button(action: {
                                try? AuthManager.shared.signOut()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            }
                            // Added top padding to separate from the cards above
                            .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, isEditing ? 40 : 100)
                    // Pushed up slightly later in animation sequence
                    .offset(y: appearAnimation ? 0 : 40)
                    .opacity(appearAnimation ? 1 : 0)
                }
            }
            
            // 4. Bottom CTA (View Mode Only)
            if !isEditing {
                Button(action: toggleEditMode) {
                    Text("Edit Profile")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primary)
                        .cornerRadius(16)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 5. Success Toast
            if showSaveToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Profile updated successfully")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 4)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }
    
    private func toggleEditMode() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if isEditing {
                // Was editing, now saving
                isEditing = false
                triggerToast()
            } else {
                // Start editing
                isEditing = true
            }
        }
    }
    
    private func triggerToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSaveToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSaveToast = false
            }
        }
    }
}

#Preview {
    DoctorProfileView()
}
