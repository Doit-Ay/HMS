import SwiftUI

// MARK: - Floating Symptom Checker Button + Overlay
// Drop this into PatientTabView as a ZStack layer over PatientHomeView

struct FloatingSymptomChecker: View {
    @State private var isExpanded = false
    @StateObject private var vm = SymptomCheckerViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // MARK: Dim background when open
            if isExpanded {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring()) { isExpanded = false } }
                    .transition(.opacity)
            }

            // MARK: Chatbot sheet
            if isExpanded {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {

                        // Handle bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 36, height: 4)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        // Header
                        HStack {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "stethoscope")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Symptom Checker")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Find the right department")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.75))
                                }
                            }
                            Spacer()
                            Button(action: {
                                withAnimation(.spring()) { isExpanded = false }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                        Divider().background(Color.white.opacity(0.2))

                        // Chat messages
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(vm.messages) { message in
                                        ChatBubble(message: message) { chip in
                                            vm.sendMessage(chip)
                                        }
                                    }

                                    // Doctor list
                                    if vm.chatState == .showingResult,
                                       let dept = vm.predictedDepartment {
                                        DoctorListPlaceholder(department: dept)
                                            .padding(.horizontal, 12)
                                    }

                                    Color.clear.frame(height: 1).id("bottom")
                                }
                                .padding(.vertical, 12)
                            }
                            .onChange(of: vm.messages.count) { _ in
                                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                            }
                        }
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                        .background(Color(.systemGroupedBackground))

                        // Input bar or restart
                        if vm.chatState != .showingResult {
                            VStack(spacing: 0) {
                                if !vm.suggestedSymptoms.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(vm.suggestedSymptoms, id: \.self) { suggestion in
                                                Button(action: {
                                                    // Haptic feedback
                                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                                    impact.impactOccurred()
                                                    vm.sendMessage(suggestion)
                                                }) {
                                                    Text(suggestion)
                                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                                        .foregroundColor(AppTheme.primary)
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 8)
                                                        .background(AppTheme.primary.opacity(0.15))
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .background(Color(.systemBackground))
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }

                                ChatInputBar(text: $vm.inputText) { text in
                                    vm.sendMessage(text)
                                }
                            }
                        } else {
                            Button(action: { vm.restart() }) {
                                Label("Check another symptom", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 14)
                                    .padding(.bottom, 38)
                            }
                            .background(Color(.systemBackground))
                        }
                    }
                    .background(
                        ZStack(alignment: .top) {
                            Color(.systemGroupedBackground)
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .topLeading,
                                endPoint: .trailing
                            )
                            .frame(height: 110)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: -10)
                    .padding(.horizontal, 0)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: Floating Action Button
            if !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .shadow(color: AppTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)

                        Image(systemName: "stethoscope")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Chat Bubble (compact version for overlay)

struct ChatBubble: View {
    let message: ChatMessage
    let onChipTap: (String) -> Void

    var body: some View {
        VStack(alignment: message.isBot ? .leading : .trailing, spacing: 6) {

            HStack {
                if !message.isBot { Spacer(minLength: 50) }

                Text(message.text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isBot ? Color(.systemBackground) : AppTheme.primary)
                    .foregroundColor(message.isBot ? AppTheme.textPrimary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if message.isBot { Spacer(minLength: 50) }
            }
            .padding(.horizontal, 12)

            // Chips
            if message.isBot && !message.chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.chips, id: \.self) { chip in
                            Button(action: { onChipTap(chip) }) {
                                Text(chip)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemBackground))
                                    .foregroundColor(AppTheme.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppTheme.primary.opacity(0.4), lineWidth: 1)
                                    )
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

// MARK: - Doctor List Placeholder (shown after department prediction)

struct DoctorListPlaceholder: View {
    let department: String

    @State private var doctors: [HMSUser] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if doctors.isEmpty {
                Text("No doctors found for \(department).")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(doctors.prefix(3)) { doctor in
                    DoctorMiniCard(doctor: doctor)
                }
            }
        }
        .task { await loadDoctors() }
    }

    private func loadDoctors() async {
        do {
            let all = try await AuthManager.shared.fetchDoctors()
            doctors = all.filter { $0.department == department }
        } catch {
            print("DoctorListPlaceholder: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Compact Doctor Card (used inside chatbot overlay)

struct DoctorMiniCard: View {
    let doctor: HMSUser

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                if let url = doctor.profileImageURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppTheme.primary)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(AppTheme.primary)
                }
            }

            // Name + department
            VStack(alignment: .leading, spacing: 3) {
                Text("Dr. \(doctor.fullName)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                if let dept = doctor.department {
                    Text(dept)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.primary.opacity(0.6))
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Chat Input Bar (compact)

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Type a symptom...", text: $text)
                .font(.system(size: 14, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(20)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(text.isEmpty ? Color(.systemGray3) : AppTheme.primary)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 38) // Replaces vertical padding to account for home indicator
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
    }
}
