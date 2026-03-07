import SwiftUI

// MARK: - Patient Tab View
struct PatientTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PatientHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle.fill")
            }
            .tag(1)
        }
        .tint(AppTheme.primary)
    }
}

// MARK: - Patient Home View
struct PatientHomeView: View {
    @ObservedObject var session = UserSession.shared
    @State private var animate  = false

    var body: some View {
        NavigationStack {
            ZStack {
                HMSBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Greeting Header Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hello, 👋")
                                        .font(.system(size: 16, design: .rounded))
                                        .foregroundColor(.white.opacity(0.85))
                                    Text(session.currentUser?.fullName.components(separatedBy: " ").first ?? "Patient")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 54, height: 54)
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                            }

                            Text("How are you feeling today?")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 4)
                        }
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryMid],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .offset(y: animate ? 0 : -20)
                        .opacity(animate ? 1 : 0)

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 14) {
                                PatientQuickAction(icon: "calendar.badge.plus",  title: "Book\nAppointment",  color: AppTheme.primary)
                                PatientQuickAction(icon: "doc.text.fill",        title: "My\nRecords",        color: AppTheme.primaryMid)
                                PatientQuickAction(icon: "pills.fill",           title: "Prescriptions",      color: AppTheme.primaryDark)
                                PatientQuickAction(icon: "waveform.path.ecg",    title: "Health\nMonitor",    color: AppTheme.primary)
                            }
                            .padding(.horizontal, 20)
                        }
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        // Health Summary Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Health Summary")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)

                            HStack(spacing: 16) {
                                HealthStatCard(icon: "heart.fill",       label: "Heart Rate",    value: "—",     unit: "bpm",  color: .red)
                                HealthStatCard(icon: "drop.fill",        label: "Blood Group",   value: session.currentUser?.bloodGroup ?? "—", unit: "",  color: AppTheme.primary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 20)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 30)
                    }
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Patient")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }
}

// MARK: - Patient Quick Action Tile
struct PatientQuickAction: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button {} label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white.opacity(0.8))
            .cornerRadius(18)
            .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Health Stat Card
struct HealthStatCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)

            Text(value + (unit.isEmpty ? "" : " \(unit)"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    PatientTabView()
}
