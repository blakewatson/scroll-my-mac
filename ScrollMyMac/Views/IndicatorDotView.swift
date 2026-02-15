import SwiftUI

struct IndicatorDotView: View {
    var body: some View {
        Circle()
            .fill(Color.black)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .frame(width: 10, height: 10)
    }
}
