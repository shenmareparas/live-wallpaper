import SwiftUI

struct WaveBarView: View {
    let isPlaying: Bool
    let delay: Double
    @State private var scale: CGFloat = 0.2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(isPlaying ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 3, height: 18)
            .scaleEffect(y: isPlaying ? scale : 0.2, anchor: .center)
            .onAppear {
                if isPlaying {
                    withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                        scale = 1.0
                    }
                }
            }
            .onChange(of: isPlaying) { playing in
                if playing {
                    withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                        scale = 1.0
                    }
                } else {
                    scale = 0.2
                }
            }
    }
}
