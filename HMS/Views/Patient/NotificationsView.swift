import SwiftUI
import FirebaseFirestore

// MARK: - Notifications View
struct NotificationsView: View {
    @ObservedObject var notificationManager = NotificationManager.shared
    @ObservedObject var session = UserSession.shared
    @State private var appearAnimation = false
    @State private var selectedTab = 0 // 0 = Unread, 1 = Read
    
    // Reschedule navigation state
    @State private var rescheduleDoctor: HMSUser? = nil
    @State private var rescheduleAppointment: Appointment? = nil
    @State private var isFetchingReschedule = false

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
            
            // Hidden NavigationLink for reschedule
            if let doctor = rescheduleDoctor, let appt = rescheduleAppointment {
                NavigationLink(
                    destination: BookAppointmentView(
                        doctor: doctor,
                        rescheduleAppointmentId: appt.id,
                        rescheduleOldSlotId: appt.slotId,
                        rescheduleDate: appt.date
                    ),
                    isActive: Binding(
                        get: { rescheduleDoctor != nil },
                        set: { if !$0 { rescheduleDoctor = nil; rescheduleAppointment = nil } }
                    )
                ) { EmptyView() }
                .hidden()
            }

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
                                    isLoadingReschedule: isFetchingReschedule
                                )
                                .onTapGesture {
                                    if !notification.isRead {
                                        Task {
                                            await notificationManager.markAsRead(notificationId: notification.id)
                                        }
                                    }
                                    // Navigate for reschedule notifications
                                    if notification.type == "reschedule_request" {
                                        Task {
                                            await handleRescheduleTap(notification)
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
    }
    
    // MARK: - Handle Reschedule Notification Tap
    private func handleRescheduleTap(_ notification: AppNotification) async {
        guard let appointmentId = notification.appointmentId,
              let doctorId = notification.doctorId,
              !isFetchingReschedule else { return }
        
        await MainActor.run { isFetchingReschedule = true }
        
        do {
            // Fetch appointment details
            let db = Firestore.firestore()
            let apptDoc = try await db.collection("appointments").document(appointmentId).getDocument()
            guard let data = apptDoc.data() else {
                await MainActor.run { isFetchingReschedule = false }
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
            let doctor = try await AuthManager.shared.fetchDoctor(id: doctorId)
            
            await MainActor.run {
                rescheduleAppointment = appointment
                rescheduleDoctor = doctor
                isFetchingReschedule = false
            }
        } catch {
            #if DEBUG
            print("Error loading reschedule data: \(error)")
            #endif
            await MainActor.run { isFetchingReschedule = false }
        }
    }
}

// MARK: - Notification Card
struct NotificationCard: View {
    let notification: AppNotification
    var isLoadingReschedule: Bool = false

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
        default: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case "reschedule_request": return .orange
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
                    HStack(spacing: 6) {
                        if isLoadingReschedule {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                            Text("Reschedule Now")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.primary)
                    .clipShape(Capsule())
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
