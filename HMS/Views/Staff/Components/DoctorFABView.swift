import SwiftUI

struct DoctorFABView: View {
    let action: () -> Void
    @State private var appearAnimation = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(appearAnimation ? 1.0 : 0.001)
        .opacity(appearAnimation ? 1.0 : 0.0)
        .onAppear {
            // "FAB bounces in after 0.5s delay"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.5)) {
                appearAnimation = true
            }
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                DoctorFABView(action: {})
                    .padding(24)
            }
        }
    }
}
