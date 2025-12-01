import SwiftUI

struct LifeBalanceChart: View {
    var focusAreas: [String]
    
    // Mock data for now, but highlighting focus areas
    // In a real app, these scores would come from user data/check-ins
    var data: [(String, Double)] {
        let allAreas = ["Health", "Wealth", "Happiness", "Productivity", "Mindfulness"]
        return allAreas.map { area in
            // Give a slightly higher 'base' score to focus areas to show they are prioritized
            let score = focusAreas.contains(area) ? 0.8 : 0.5
            return (area, score)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Life Balance")
                .font(.title3.bold())
                .padding(.horizontal)
            
            ZStack {
                // Background Web
                RadarChartGrid(sides: data.count, rings: 4)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                
                // Data Shape
                RadarChartShape(data: data.map { $0.1 })
                    .fill(Color.clarityBlue.opacity(0.3))
                    .overlay(
                        RadarChartShape(data: data.map { $0.1 })
                            .stroke(Color.clarityBlue, lineWidth: 2)
                    )
                
                // Labels
                RadarLabels(data: data)
            }
            .frame(height: 250)
            .padding()
        }
        .cardStyle()
    }
}

// MARK: - Drawing Helpers

struct RadarChartGrid: Shape {
    var sides: Int
    var rings: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2 * Double.pi / Double(sides)
        
        // Draw rings
        for i in 1...rings {
            let ringRadius = radius * Double(i) / Double(rings)
            let startPoint = CGPoint(
                x: center.x + CGFloat(cos(-Double.pi / 2)) * ringRadius,
                y: center.y + CGFloat(sin(-Double.pi / 2)) * ringRadius
            )
            path.move(to: startPoint)
            
            for j in 1...sides {
                let currentAngle = -Double.pi / 2 + angle * Double(j)
                let point = CGPoint(
                    x: center.x + CGFloat(cos(currentAngle)) * ringRadius,
                    y: center.y + CGFloat(sin(currentAngle)) * ringRadius
                )
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        
        // Draw spokes
        for i in 0..<sides {
            let currentAngle = -Double.pi / 2 + angle * Double(i)
            let endPoint = CGPoint(
                x: center.x + CGFloat(cos(currentAngle)) * radius,
                y: center.y + CGFloat(sin(currentAngle)) * radius
            )
            path.move(to: center)
            path.addLine(to: endPoint)
        }
        
        return path
    }
}

struct RadarChartShape: Shape {
    var data: [Double] // Values between 0.0 and 1.0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angle = 2 * Double.pi / Double(data.count)
        
        for (index, value) in data.enumerated() {
            let currentAngle = -Double.pi / 2 + angle * Double(index)
            let pointRadius = radius * value
            let point = CGPoint(
                x: center.x + CGFloat(cos(currentAngle)) * pointRadius,
                y: center.y + CGFloat(sin(currentAngle)) * pointRadius
            )
            
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

struct RadarLabels: View {
    var data: [(String, Double)]
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let angle = 2 * Double.pi / Double(data.count)
            
            ForEach(0..<data.count, id: \.self) { index in
                let currentAngle = -Double.pi / 2 + angle * Double(index)
                // Push labels out slightly further than the radius
                let labelRadius = radius + 20 
                let x = center.x + CGFloat(cos(currentAngle)) * labelRadius
                let y = center.y + CGFloat(sin(currentAngle)) * labelRadius
                
                Text(data[index].0)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .position(x: x, y: y)
            }
        }
    }
}
