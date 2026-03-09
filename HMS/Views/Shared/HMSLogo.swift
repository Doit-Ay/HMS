import SwiftUI

// MARK: - HMS Logo (Heart + Cross)
/// Brand logo matching the reference: large heart with white border,
/// light-teal fill, and a prominent teal medical cross inside.
struct HMSLogo: View {
    var size: CGFloat = 80

    private var heartSize: CGFloat { size }
    private var crossSize: CGFloat { size * 0.50 }
    private var crossThickness: CGFloat { size * 0.18 }
    private var crossCorner: CGFloat { size * 0.05 }

    var body: some View {
        ZStack {
            // Outer heart — white border / glow//jbjb
            HeartShape()
                .fill(Color.white)
                .frame(width: heartSize, height: heartSize * 0.92)
                .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)

            // Inner heart — light teal gradient fill
            HeartShape()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryLight,
                            AppTheme.primaryMid.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: heartSize * 0.85, height: heartSize * 0.78)

            // Medical Cross — teal with subtle gloss
            ZStack {
                // Shadow cross (depth)
                CrossShape(thickness: crossThickness, cornerRadius: crossCorner)
                    .fill(AppTheme.primary.opacity(0.25))
                    .frame(width: crossSize, height: crossSize)
                    .offset(x: 2, y: 2)

                // Main cross
                CrossShape(thickness: crossThickness, cornerRadius: crossCorner)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryMid],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: crossSize, height: crossSize)

                // Gloss highlight on cross
                CrossShape(thickness: crossThickness * 0.55, cornerRadius: crossCorner * 0.6)
                    .fill(Color.white.opacity(0.35))
                    .frame(width: crossSize * 0.55, height: crossSize * 0.55)
                    .offset(x: -crossSize * 0.06, y: -crossSize * 0.06)
            }
            .offset(y: -size * 0.02)
        }
    }
}

// MARK: - Cross Shape
struct CrossShape: Shape {
    var thickness: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let t = thickness
        let cx = w / 2
        let cy = h / 2
        let r = cornerRadius

        var path = Path()

        // Horizontal bar
        path.addRoundedRect(
            in: CGRect(x: 0, y: cy - t / 2, width: w, height: t),
            cornerSize: CGSize(width: r, height: r)
        )

        // Vertical bar
        path.addRoundedRect(
            in: CGRect(x: cx - t / 2, y: 0, width: t, height: h),
            cornerSize: CGSize(width: r, height: r)
        )

        return path
    }
}

// MARK: - Heart Shape
struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        // Bottom tip
        let bottom = CGPoint(x: w * 0.5, y: h)

        path.move(to: bottom)

        // Left curve
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.25),
            control1: CGPoint(x: w * 0.12, y: h * 0.72),
            control2: CGPoint(x: 0, y: h * 0.50)
        )

        // Left top lobe
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.18),
            control1: CGPoint(x: 0, y: -h * 0.05),
            control2: CGPoint(x: w * 0.42, y: h * 0.06)
        )

        // Right top lobe
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.25),
            control1: CGPoint(x: w * 0.58, y: h * 0.06),
            control2: CGPoint(x: w, y: -h * 0.05)
        )

        // Right curve back to bottom
        path.addCurve(
            to: bottom,
            control1: CGPoint(x: w, y: h * 0.50),
            control2: CGPoint(x: w * 0.88, y: h * 0.72)
        )

        return path
    }
}

#Preview {
    ZStack {
        HMSBackground()
        VStack(spacing: 30) {
            HMSLogo(size: 120)
            HMSLogo(size: 80)
            HMSLogo(size: 50)
        }
    }
}
