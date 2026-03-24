import SwiftUI
import Combine

struct AudioVisualizerView: View {
    let isRecording: Bool
    let color: Color
    
    @State private var heights: [CGFloat] = Array(repeating: 8, count: 6)
    
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<heights.count, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 4, height: isRecording ? heights[index] : 8)
                    .animation(.easeInOut(duration: 0.15), value: heights[index])
            }
        }
        .frame(height: 30)
        .onReceive(timer) { _ in
            if isRecording {
                for i in 0..<heights.count {
                    heights[i] = CGFloat.random(in: 8...30)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioVisualizerView(isRecording: true, color: .green)
        AudioVisualizerView(isRecording: false, color: .green)
    }
}
