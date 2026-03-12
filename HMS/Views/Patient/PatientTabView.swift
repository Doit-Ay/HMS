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
    @State private var animate = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                AppTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primaryLight.opacity(0.8), AppTheme.primaryLight.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {

                        HeaderProfileView(session: session)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .offset(y: animate ? 0 : -30)
                            .opacity(animate ? 1 : 0)

                        VStack(spacing: 0) {

                            HStack {
                                VStack(alignment: .leading, spacing: 8) {

                                    Text("Your Health,\nOur Priority")
                                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineSpacing(4)

                                    Text("Find the right doctor and book your appointment easily.")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding(.trailing, 40)
                                }

                                Spacer()
                            }
                            .padding(24)

                            NavigationLink(destination: DoctorSearchView()) {

                                HStack {
                                    Text("Book Appointment")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))

                                    Spacer()

                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 24))
                                }
                                .foregroundColor(AppTheme.primary)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            ZStack {

                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.primaryMid],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 180))
                                    .foregroundColor(.white.opacity(0.1))
                                    .offset(x: 100, y: 20)
                                    .rotationEffect(.degrees(-15))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .shadow(color: AppTheme.primary.opacity(0.25), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 20)
                        .offset(y: animate ? 0 : 30)
                        .opacity(animate ? 1 : 0)

                        VStack(alignment: .leading, spacing: 20) {

                            Text("Top Services")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal, 24)

                            HStack(spacing: 16) {

                                FeatureTile(icon: "doc.text.fill", title: "Records", color: AppTheme.primaryDark)
                                FeatureTile(icon: "pills.fill", title: "Pharmacy", color: AppTheme.primaryMid)
                                FeatureTile(icon: "waveform.path.ecg", title: "Monitor", color: AppTheme.primary)
                            }
                            .padding(.horizontal, 20)
                        }
                        .offset(y: animate ? 0 : 40)
                        .opacity(animate ? 1 : 0)

                        VStack(alignment: .leading, spacing: 20) {

                            HStack {

                                Text("Vitals Overview")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Button {

                                } label: {

                                    Text("See all")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            .padding(.horizontal, 24)

                            VStack(spacing: 16) {

                                VitalRow(
                                    icon: "heart.fill",
                                    title: "Heart Rate",
                                    value: "—",
                                    unit: "bpm",
                                    iconColor: .red
                                )

                                VitalRow(
                                    icon: "drop.fill",
                                    title: "Blood Group",
                                    value: session.currentUser?.bloodGroup ?? "—",
                                    unit: "",
                                    iconColor: AppTheme.primary
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        .offset(y: animate ? 0 : 50)
                        .opacity(animate ? 1 : 0)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                animate = true
            }
        }
    }
}

// MARK: - Vital Row (FIX ADDED)
struct VitalRow: View {

    let icon: String
    let title: String
    let value: String
    let unit: String
    let iconColor: Color

    var body: some View {

        HStack(spacing: 16) {

            ZStack {

                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text(value + (unit.isEmpty ? "" : " \(unit)"))
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Header Profile View
struct HeaderProfileView: View {

    @ObservedObject var session: UserSession

    var body: some View {

        HStack {

            VStack(alignment: .leading, spacing: 6) {

                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.primary)
                    .textCase(.uppercase)

                HStack(spacing: 6) {

                    Text("Hi,")
                        .font(.system(size: 28, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)

                    Text(session.currentUser?.fullName.components(separatedBy: " ").first ?? "Patient")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
            }

            Spacer()

            ZStack {

                Circle()
                    .stroke(AppTheme.primaryMid.opacity(0.3), lineWidth: 2)
                    .frame(width: 58, height: 58)

                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(AppTheme.primaryDark)
                    .background(Circle().fill(AppTheme.primaryLight))
            }
        }
    }
}

// MARK: - Feature Tile
struct FeatureTile: View {

    let icon: String
    let title: String
    let color: Color

    var body: some View {

        Button {} label: {

            VStack(spacing: 16) {

                ZStack {

                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 54, height: 54)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: AppTheme.textSecondary.opacity(0.08), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PatientTabView()
}
