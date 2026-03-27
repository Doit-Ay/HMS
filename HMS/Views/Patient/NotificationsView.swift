import SwiftUI
import FirebaseFirestore

// MARK: - Notifications View
struct NotificationsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @ObservedObject var session = UserSession.shared
    @State private var appearAnimation = false
    @State private var selectedTab = 0 // 0 = Unread, 1 = Read
    
    // Reschedule navigation state
    @State private var navigateToReschedule = false
    @State private var rescheduleDoctor: HMSUser? = nil
    @State private var rescheduleAppointment: Appointment? = nil
    @State private var rescheduleNotificationId: String? = nil
    @State private var loadingNotificationId: String? = nil
    @State private var errorMessage: String? = nil

    private var unreadNotifications: [AppNotification] {
        notificationManager.notifications.filter { !$0.isRead }
    }

    private var readNotifications: [AppNotification] {
        notificationManager.notifications.filter { $0.isRead }
    }

    private var displayedNotifications: [AppNotification] {
        selectedTab == 0 ? unreadNotifications : readNotifications
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Segmented Control
                Picker("", selection: $selectedTab) {
                    Text("Unread (\(unreadNotifications.count))").tag(0)
                    Text("Read").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if displayedNotifications.isEmpty {
                    // Empty state
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: selectedTab == 0 ? "bell.slash.fill" : "tray.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.35))

                        Text(selectedTab == 0 ? "No unread notifications" : "No read notifications")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.textSecondary)

                        if selectedTab == 0 {
                            Text("You're all caught up!")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .offset(y: appearAnimation ? 0 : 20)
                    .opacity(appearAnimation ? 1 : 0)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(displayedNotifications) { notification in
                                NotificationCard(
                                    notification: notification,
                                    isLoadingReschedule: loadingNotificationId == notification.id,
                                    onRescheduleTap: {
                                        Task {
                                            // Mark as read first
                                            if !notification.isRead {
                                                await notificationManager.markAsRead(notificationId: notification.id)
                                            }
                                            await handleRescheduleTap(notification)
                                        }
                                    }
                                )
                                .onTapGesture {
                                    // Only mark as read on general tap — don't navigate
                                    if !notification.isRead {
                                        Task {
                                            await notificationManager.markAsRead(notificationId: notification.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .padding(.bottom, 30)
                    }
                    .offset(y: appearAnimation ? 0 : 20)
                    .opacity(appearAnimation ? 1 : 0)
                }
                
                // Error banner
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            withAnimation { errorMessage = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.cardSurface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if notificationManager.unreadCount > 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if let userId = session.currentUser?.id {
                            Task {
                                await notificationManager.markAllAsRead(for: userId)
                            }
                        }
                    } label: {
                        Text("Mark all read")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appearAnimation = true
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToReschedule) {
            if let doctor = rescheduleDoctor, let appt = rescheduleAppointment {
                BookAppointmentView(
                    doctor: doctor,
                    rescheduleAppointmentId: appt.id,
                    rescheduleOldSlotId: appt.slotId,
                    rescheduleDate: appt.date,
                    rescheduleNotificationId: rescheduleNotificationId
                )
            }
        }
    }
    
    // MARK: - Handle Reschedule Notification Tap
    private func handleRescheduleTap(_ notification: AppNotification) async {
        guard let appointmentId = notification.appointmentId,
              let doctorId = notification.doctorId,
              loadingNotificationId == nil else { return }
        
        await MainActor.run {
            loadingNotificationId = notification.id
            errorMessage = nil
        }
        
        do {
            // Fetch appointment details
            let db = Firestore.firestore()
            let apptDoc = try await db.collection("appointments").document(appointmentId).getDocument()
            guard let data = apptDoc.data() else {
                await MainActor.run {
                    loadingNotificationId = nil
                    withAnimation { errorMessage = "Appointment not found." }
                }
                return
            }
            
            let appointment = Appointment(
                id: appointmentId,
                slotId: data["slotId"] as? String ?? "",
                doctorId: data["doctorId"] as? String ?? doctorId,
                doctorName: data["doctorName"] as? String ?? "",
                patientId: data["patientId"] as? String ?? "",
                patientName: data["patientName"] as? String ?? "",
                department: data["department"] as? String,
                date: data["date"] as? String ?? "",
                startTime: data["startTime"] as? String ?? "",
                endTime: data["endTime"] as? String ?? "",
                status: data["status"] as? String ?? "cancelled",
                cancelReason: data["cancelReason"] as? String
            )
            
            // Fetch doctor
            guard let doctor = try await AuthManager.shared.fetchDoctor(id: doctorId) else {
                await MainActor.run {
                    loadingNotificationId = nil
                    withAnimation { errorMessage = "Doctor profile not found." }
                }
                return
            }
            
            await MainActor.run {
                rescheduleAppointment = appointment
                rescheduleDoctor = doctor
                rescheduleNotificationId = notification.id
                loadingNotificationId = nil
                navigateToReschedule = true
            }
        } catch {
            #if DEBUG
            print("Error loading reschedule data: \(error)")
            #endif
            await MainActor.run {
                loadingNotificationId = nil
                withAnimation { errorMessage = "Could not load appointment details." }
            }
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: AppNotification
    var isLoadingReschedule: Bool = false
    var onRescheduleTap: (() -> Void)? = nil

    private var timeAgoString: String {
        let interval = Date().timeIntervalSince(notification.createdAt)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: notification.createdAt)
    }

    private var iconName: String {
        switch notification.type {
        case "reschedule_request": return "calendar.badge.exclamationmark"
        case "reschedule_completed": return "checkmark.circle.fill"
        default: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case "reschedule_request": return .orange
        case "reschedule_completed": return .green
        default: return AppTheme.primary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Spacer()

                    // Unread indicator
                    if !notification.isRead {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(notification.message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Reschedule action button
                if notification.type == "reschedule_request" && notification.appointmentId != nil {
                    Button {
                        onRescheduleTap?()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoadingReschedule {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Loading…")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Reschedule Now")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isLoadingReschedule
                                ? AnyShapeStyle(AppTheme.primary.opacity(0.7))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .leading, endPoint: .trailing
                                  ))
                        )
                        .clipShape(Capsule())
                        .opacity(isLoadingReschedule ? 0.85 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingReschedule)
                    .padding(.top, 4)
                }
                
                // Rescheduled badge
                if notification.type == "reschedule_completed" {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Rescheduled")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.green)
                    .padding(.top, 4)
                }

                Text(timeAgoString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            ZStack {
                AppTheme.cardSurface
                if !notification.isRead {
                    AppTheme.primary.opacity(0.04)
                }
            }
        )
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
