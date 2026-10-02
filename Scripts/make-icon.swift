// Renders Resources/AppIcon.icns. Run: swift Scripts/make-icon.swift
import AppKit
import SwiftUI

struct Icon: View {
    private let corner: CGFloat = 185

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(
                colors: [Color(red: 0.24, green: 0.20, blue: 0.22), Color(red: 0.10, green: 0.08, blue: 0.10)],
                startPoint: .top, endPoint: .bottom))

            // Light caught inside the glass at the two lit corners.
            cornerGlow(.topLeading, color: Color(red: 1.0, green: 0.78, blue: 0.55))
            cornerGlow(.bottomTrailing, color: Color(red: 0.75, green: 0.80, blue: 1.0))

            // Sheen across the upper half of the pane.
            shape.fill(LinearGradient(colors: [.white.opacity(0.14), .clear],
                                      startPoint: .top, endPoint: .center))

            cup.offset(y: 40)

            // Specular rim: a hairline everywhere, bright only at the top-left and bottom-right corners.
            shape.strokeBorder(.white.opacity(0.12), lineWidth: 3)
            ZStack {
                shape.strokeBorder(.white, lineWidth: 9)
                shape.strokeBorder(.white, lineWidth: 34).blur(radius: 22).opacity(0.75)
            }
            .mask(ZStack {
                RadialGradient(colors: [.white, .clear], center: .topLeading, startRadius: 60, endRadius: 440)
                RadialGradient(colors: [.white.opacity(0.8), .clear], center: .bottomTrailing, startRadius: 60, endRadius: 380)
            })
        }
        .frame(width: 824, height: 824)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 22, y: 12)
        .frame(width: 1024, height: 1024)
    }

    private func cornerGlow(_ corner: UnitPoint, color: Color) -> some View {
        RadialGradient(colors: [color.opacity(0.45), .clear], center: corner, startRadius: 0, endRadius: 430)
    }

    private var cup: some View {
        let symbol = Image(systemName: "cup.and.saucer.fill").font(.system(size: 330, weight: .medium))
        let outline = Image(systemName: "cup.and.saucer").font(.system(size: 330, weight: .medium))
        // Edge light falls from the top-left and bounces back at the bottom-right, like the rim.
        let edgeLight = LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white.opacity(0.55), location: 0.45),
            .init(color: .white.opacity(0.55), location: 0.6),
            .init(color: Color(red: 1.0, green: 0.85, blue: 0.7), location: 1),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)

        return ZStack {
            Steam()
                .fill(edgeLight)
                .frame(width: 110, height: 190)
                .offset(x: -24, y: -226)
            // Frosted body: the dark pane shows through.
            symbol.foregroundStyle(LinearGradient(
                colors: [.white.opacity(0.55), Color(red: 1.0, green: 0.72, blue: 0.45).opacity(0.30)],
                startPoint: .top, endPoint: .bottom))
            edgeLight.mask(outline)
        }
        .shadow(color: Color(red: 1.0, green: 0.62, blue: 0.32).opacity(0.55), radius: 40)
    }
}

/// The same S-shaped petal as the menu bar glyph.
struct Steam: Shape {
    func path(in rect: CGRect) -> Path {
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let sway = rect.width * 0.5
        let width = rect.width * 0.32
        let c1 = CGPoint(x: base.x + sway, y: rect.maxY - rect.height * 0.33)
        let c2 = CGPoint(x: base.x - sway, y: rect.maxY - rect.height * 0.67)
        var path = Path()
        path.move(to: base)
        path.addCurve(to: top, control1: CGPoint(x: c1.x - width, y: c1.y), control2: CGPoint(x: c2.x - width, y: c2.y))
        path.addCurve(to: base, control1: CGPoint(x: c2.x + width, y: c2.y), control2: CGPoint(x: c1.x + width, y: c1.y))
        path.closeSubpath()
        return path
    }
}

@MainActor
func render(size: Int) -> Data {
    let renderer = ImageRenderer(content: Icon().scaleEffect(CGFloat(size) / 1024).frame(width: CGFloat(size), height: CGFloat(size)))
    renderer.scale = 1
    let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! MainActor.assumeIsolated { render(size: base * scale) }.write(to: iconset.appendingPathComponent(name))
    }
}
try! MainActor.assumeIsolated { render(size: 1024) }.write(to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Resources/AppIcon.icns written" : "iconutil failed")
