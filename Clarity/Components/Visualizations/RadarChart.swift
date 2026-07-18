import SwiftUI

struct RadarChart: View {
    let data: [Double]
    let max: Double = 100
    let labels: [String]
    let colors: [Color]
    let gridColor: Color = .white.opacity(0.14)
    let dataColor: Color = .clarityBlue
    
    // Animation state
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 * 0.8
            
            content(center: center, radius: radius)
        }
    }
    
    private func content(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            gridLayers(center: center, radius: radius)
            axisLines(center: center, radius: radius)
            labelsLayer(center: center, radius: radius)
            polygonLayer(center: center, radius: radius)
        }
        .onAppear {
            progress = 1.0
        }
    }
    
    // MARK: - Subviews
    
    // MARK: - Subviews
    
    private func gridLayers(center: CGPoint, radius: CGFloat) -> some View {
        let scales: [Double] = [0.25, 0.5, 0.75, 1.0]
        return ForEach(scales, id: \.self) { scale in
            RadarGrid(sides: data.count, radius: radius * CGFloat(scale), center: center)
                .stroke(gridColor, style: StrokeStyle(lineWidth: 1, dash: scale == 1.0 ? [] : [5]))
        }
    }
    
    private func axisLines(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(0..<data.count, id: \.self) { i in
            let point = self.point(for: i, radius: radius, center: center)
            Path { path in
                path.move(to: center)
                path.addLine(to: point)
            }
            .stroke(gridColor, lineWidth: 1)
        }
    }
    
    private func labelsLayer(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(0..<data.count, id: \.self) { i in
            let labelRadius = radius * 1.25
            let point = self.point(for: i, radius: labelRadius, center: center)
            
            VStack {
                Text(labels[safe: i] ?? "")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .position(point)
        }
    }
    
    private func polygonLayer(center: CGPoint, radius: CGFloat) -> some View {
        ZStack {
            RadarPolygon(data: data, max: max, center: center, radius: radius, sides: data.count)
                .fill(LinearGradient(
                    colors: [dataColor.opacity(0.55), dataColor.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .scaleEffect(progress)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: progress)

            // Neon glow pass behind the crisp stroke
            RadarPolygon(data: data, max: max, center: center, radius: radius, sides: data.count)
                .stroke(dataColor, lineWidth: 6)
                .blur(radius: 8)
                .opacity(0.6)
                .scaleEffect(progress)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: progress)

            RadarPolygon(data: data, max: max, center: center, radius: radius, sides: data.count)
                .stroke(dataColor, lineWidth: 2.5)
                .scaleEffect(progress)
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: progress)
        }
    }
    
    // MARK: - Helpers
    
    private func point(for index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = (Double(index) * 360.0 / Double(data.count) - 90.0) * .pi / 180.0
        return CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}

// MARK: - Shapes

struct RadarGrid: Shape {
    let sides: Int
    let radius: CGFloat
    let center: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard sides > 0 else { return path }
        let angleIncrement = 360.0 / Double(sides)
        
        for i in 0..<sides {
            let angle = (Double(i) * angleIncrement - 90.0) * .pi / 180.0
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarPolygon: Shape {
    let data: [Double]
    let max: Double
    let center: CGPoint
    let radius: CGFloat
    let sides: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard sides > 0 else { return path }
        let angleIncrement = 360.0 / Double(sides)
        
        for i in 0..<sides {
            let angle = (Double(i) * angleIncrement - 90.0) * .pi / 180.0
            let value = data[safe: i] ?? 0
            // Normalize value (clamp between 5 and max to ensure consistent shape visibility)
            let normalizedValue = Swift.max(5, Swift.min(value, max)) / max
            
            let point = CGPoint(
                x: center.x + (radius * CGFloat(normalizedValue)) * CGFloat(cos(angle)),
                y: center.y + (radius * CGFloat(normalizedValue)) * CGFloat(sin(angle))
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

// Safe array subscript
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RadarChart(
            data: [85, 70, 92, 60, 45],
            labels: ["Tasks", "Habits", "Mood", "Moments", "Finance"],
            colors: [.red, .green, .blue, .yellow, .purple]
        )
        .frame(width: 300, height: 300)
    }
}
