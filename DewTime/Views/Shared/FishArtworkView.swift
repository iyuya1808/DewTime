import SwiftUI

struct FishArtworkView: View {
    let species: FishSpecies
    var tint: Color? = nil
    var isLocked: Bool = false
    var facingRight: Bool = true

    var body: some View {
        Canvas { context, size in
            var ctx = context
            if !facingRight {
                ctx.translateBy(x: size.width, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            FishArtworkRenderer.draw(
                species,
                in: CGRect(origin: .zero, size: size),
                context: &ctx,
                tint: tint,
                opacity: isLocked ? 0.35 : 1
            )
        }
        .accessibilityLabel(species.displayName)
    }
}

private class BundleFinder {}

enum FishArtworkRenderer {
    static func draw(
        _ species: FishSpecies,
        in rect: CGRect,
        context: inout GraphicsContext,
        tint: Color? = nil,
        opacity: Double = 1
    ) {
        var ctx = context
        ctx.opacity *= opacity

        let assetName = "fish_\(species.rawValue)"
        let bundle = Bundle(for: BundleFinder.self)
        if UIImage(named: assetName, in: bundle, compatibleWith: nil) != nil {
            let resolvedImage = ctx.resolve(Image(assetName))
            if let tint {
                var tintedCtx = ctx
                tintedCtx.addFilter(.colorMultiply(tint))
                tintedCtx.draw(resolvedImage, in: rect)
            } else {
                ctx.draw(resolvedImage, in: rect)
            }
        } else {
            let palette = palette(for: species, tint: tint)
            switch species {
            case .shrimp:
                drawShrimp(in: rect, context: &ctx, palette: palette)
            case .crab:
                drawCrab(in: rect, context: &ctx, palette: palette)
            case .turtle:
                drawTurtle(in: rect, context: &ctx, palette: palette)
            case .squid:
                drawSquid(in: rect, context: &ctx, palette: palette)
            case .octopus:
                drawOctopus(in: rect, context: &ctx, palette: palette)
            case .lobster:
                drawLobster(in: rect, context: &ctx, palette: palette)
            case .jellyfish:
                drawJellyfish(in: rect, context: &ctx, palette: palette)
            case .seal:
                drawSeal(in: rect, context: &ctx, palette: palette)
            case .dolphin:
                drawLongFish(in: rect, context: &ctx, palette: palette, dorsal: true, beak: true)
            case .shark:
                drawLongFish(in: rect, context: &ctx, palette: palette, dorsal: true, beak: false)
            case .whale, .whaleShark:
                drawWhale(in: rect, context: &ctx, palette: palette, spotted: species == .whaleShark)
            case .pufferfish:
                drawPuffer(in: rect, context: &ctx, palette: palette)
            case .medaka, .guppy:
                drawSmallFish(in: rect, context: &ctx, palette: palette, fancyTail: species == .guppy)
            }
        }
    }

    private struct Palette {
        let body: Color
        let belly: Color
        let fin: Color
        let accent: Color
        let eye: Color = Color(red: 0.05, green: 0.12, blue: 0.18)
    }

    private static func palette(for species: FishSpecies, tint: Color?) -> Palette {
        if let tint {
            return Palette(body: tint, belly: tint.opacity(0.42), fin: tint.opacity(0.82), accent: .white.opacity(0.82))
        }
        switch species {
        case .medaka: return Palette(body: Color(hex: "#7DD3FC"), belly: Color(hex: "#DFF8FF"), fin: Color(hex: "#38BDF8"), accent: Color(hex: "#FDE68A"))
        case .guppy: return Palette(body: Color(hex: "#34D399"), belly: Color(hex: "#D1FAE5"), fin: Color(hex: "#F472B6"), accent: Color(hex: "#FDE68A"))
        case .shrimp, .lobster, .crab: return Palette(body: Color(hex: "#FB7185"), belly: Color(hex: "#FFE4E6"), fin: Color(hex: "#F43F5E"), accent: Color(hex: "#FDA4AF"))
        case .pufferfish: return Palette(body: Color(hex: "#FBBF24"), belly: Color(hex: "#FEF3C7"), fin: Color(hex: "#F59E0B"), accent: Color(hex: "#FFFFFF"))
        case .turtle: return Palette(body: Color(hex: "#22C55E"), belly: Color(hex: "#BBF7D0"), fin: Color(hex: "#15803D"), accent: Color(hex: "#84CC16"))
        case .squid, .octopus: return Palette(body: Color(hex: "#A78BFA"), belly: Color(hex: "#EDE9FE"), fin: Color(hex: "#7C3AED"), accent: Color(hex: "#F0ABFC"))
        case .jellyfish: return Palette(body: Color(hex: "#67E8F9"), belly: Color(hex: "#ECFEFF"), fin: Color(hex: "#22D3EE"), accent: Color(hex: "#F0ABFC"))
        case .seal: return Palette(body: Color(hex: "#CBD5E1"), belly: Color(hex: "#F8FAFC"), fin: Color(hex: "#94A3B8"), accent: Color(hex: "#E2E8F0"))
        case .dolphin: return Palette(body: Color(hex: "#38BDF8"), belly: Color(hex: "#E0F2FE"), fin: Color(hex: "#0284C7"), accent: Color(hex: "#BAE6FD"))
        case .shark: return Palette(body: Color(hex: "#64748B"), belly: Color(hex: "#E2E8F0"), fin: Color(hex: "#334155"), accent: Color(hex: "#F8FAFC"))
        case .whale: return Palette(body: Color(hex: "#2563EB"), belly: Color(hex: "#DBEAFE"), fin: Color(hex: "#1D4ED8"), accent: Color(hex: "#93C5FD"))
        case .whaleShark: return Palette(body: Color(hex: "#0F766E"), belly: Color(hex: "#CCFBF1"), fin: Color(hex: "#115E59"), accent: Color(hex: "#ECFEFF"))
        }
    }

    private static func drawSmallFish(in r: CGRect, context: inout GraphicsContext, palette: Palette, fancyTail: Bool) {
        let body = oval(r, x: 0.22, y: 0.28, w: 0.52, h: 0.44)
        context.fill(tail(r, x: 0.16, y: 0.5, w: fancyTail ? 0.22 : 0.16, h: fancyTail ? 0.48 : 0.34), with: .color(palette.fin))
        context.fill(body, with: .linearGradient(Gradient(colors: [palette.body, palette.belly]), startPoint: point(r, 0.45, 0.25), endPoint: point(r, 0.55, 0.75)))
        context.fill(fin(r, top: true), with: .color(palette.fin.opacity(0.86)))
        context.fill(fin(r, top: false), with: .color(palette.fin.opacity(0.65)))
        context.fill(Path(ellipseIn: rect(r, x: 0.62, y: 0.39, w: 0.07, h: 0.07)), with: .color(palette.eye))
        if fancyTail {
            context.stroke(stripe(r, y: 0.43), with: .color(palette.accent.opacity(0.9)), lineWidth: max(1, r.width * 0.025))
            context.stroke(stripe(r, y: 0.56), with: .color(palette.accent.opacity(0.7)), lineWidth: max(1, r.width * 0.02))
        }
    }

    private static func drawPuffer(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(tail(r, x: 0.13, y: 0.5, w: 0.18, h: 0.3), with: .color(palette.fin))
        context.fill(Path(ellipseIn: rect(r, x: 0.24, y: 0.18, w: 0.56, h: 0.62)), with: .color(palette.body))
        context.fill(Path(ellipseIn: rect(r, x: 0.32, y: 0.45, w: 0.38, h: 0.24)), with: .color(palette.belly.opacity(0.88)))
        context.fill(fin(r, top: false), with: .color(palette.fin.opacity(0.7)))
        for x in stride(from: 0.34, through: 0.66, by: 0.16) {
            context.fill(Path(ellipseIn: rect(r, x: x, y: 0.33, w: 0.035, h: 0.035)), with: .color(.white.opacity(0.75)))
        }
        context.fill(Path(ellipseIn: rect(r, x: 0.63, y: 0.35, w: 0.07, h: 0.07)), with: .color(palette.eye))
    }

    private static func drawLongFish(in r: CGRect, context: inout GraphicsContext, palette: Palette, dorsal: Bool, beak: Bool) {
        let body = Path { p in
            p.move(to: point(r, 0.16, 0.52))
            p.addCurve(to: point(r, 0.72, 0.27), control1: point(r, 0.34, 0.18), control2: point(r, 0.58, 0.20))
            p.addCurve(to: point(r, beak ? 0.94 : 0.86, 0.48), control1: point(r, 0.82, 0.30), control2: point(r, 0.9, 0.38))
            p.addCurve(to: point(r, 0.72, 0.68), control1: point(r, 0.9, 0.58), control2: point(r, 0.82, 0.66))
            p.addCurve(to: point(r, 0.16, 0.52), control1: point(r, 0.52, 0.82), control2: point(r, 0.31, 0.76))
            p.closeSubpath()
        }
        context.fill(tail(r, x: 0.08, y: 0.52, w: 0.2, h: 0.42), with: .color(palette.fin))
        context.fill(body, with: .color(palette.body))
        context.fill(belly(r), with: .color(palette.belly.opacity(0.8)))
        if dorsal { context.fill(dorsalFin(r), with: .color(palette.fin)) }
        context.fill(pectoralFin(r), with: .color(palette.fin.opacity(0.78)))
        context.fill(Path(ellipseIn: rect(r, x: 0.72, y: 0.38, w: 0.055, h: 0.055)), with: .color(palette.eye))
    }

    private static func drawWhale(in r: CGRect, context: inout GraphicsContext, palette: Palette, spotted: Bool) {
        context.fill(tail(r, x: 0.08, y: 0.5, w: 0.2, h: 0.38), with: .color(palette.fin))
        context.fill(Path(ellipseIn: rect(r, x: 0.21, y: 0.2, w: 0.64, h: 0.56)), with: .color(palette.body))
        context.fill(Path(ellipseIn: rect(r, x: 0.29, y: 0.47, w: 0.46, h: 0.22)), with: .color(palette.belly.opacity(0.88)))
        context.fill(pectoralFin(r), with: .color(palette.fin.opacity(0.76)))
        if spotted {
            for (x, y) in [(0.42, 0.34), (0.52, 0.29), (0.61, 0.38), (0.70, 0.32)] {
                context.fill(Path(ellipseIn: rect(r, x: x, y: y, w: 0.035, h: 0.035)), with: .color(palette.accent.opacity(0.8)))
            }
        }
        context.fill(Path(ellipseIn: rect(r, x: 0.69, y: 0.38, w: 0.055, h: 0.055)), with: .color(palette.eye))
    }

    private static func drawShrimp(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.stroke(curve(r, from: (0.15, 0.36), c1: (0.36, 0.1), c2: (0.68, 0.28), to: (0.74, 0.58)), with: .color(palette.body), style: StrokeStyle(lineWidth: max(5, r.width * 0.16), lineCap: .round))
        context.stroke(curve(r, from: (0.21, 0.34), c1: (0.4, 0.18), c2: (0.64, 0.32), to: (0.67, 0.54)), with: .color(palette.belly.opacity(0.45)), style: StrokeStyle(lineWidth: max(2, r.width * 0.04), lineCap: .round))
        context.stroke(curve(r, from: (0.74, 0.46), c1: (0.88, 0.34), c2: (0.95, 0.38), to: (0.98, 0.24)), with: .color(palette.fin), lineWidth: max(1, r.width * 0.025))
        context.stroke(curve(r, from: (0.74, 0.52), c1: (0.9, 0.52), c2: (0.96, 0.62), to: (0.98, 0.78)), with: .color(palette.fin), lineWidth: max(1, r.width * 0.025))
        context.fill(Path(ellipseIn: rect(r, x: 0.68, y: 0.34, w: 0.055, h: 0.055)), with: .color(palette.eye))
        context.fill(tail(r, x: 0.05, y: 0.4, w: 0.17, h: 0.28), with: .color(palette.fin.opacity(0.78)))
    }

    private static func drawCrab(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(Path(ellipseIn: rect(r, x: 0.28, y: 0.28, w: 0.44, h: 0.34)), with: .color(palette.body))
        for x in [0.3, 0.42, 0.58, 0.7] {
            context.stroke(curve(r, from: (x, 0.58), c1: (x - 0.05, 0.7), c2: (x - 0.02, 0.76), to: (x - 0.08, 0.83)), with: .color(palette.fin), lineWidth: max(1.5, r.width * 0.035))
        }
        context.stroke(curve(r, from: (0.28, 0.4), c1: (0.16, 0.24), c2: (0.09, 0.27), to: (0.06, 0.16)), with: .color(palette.fin), lineWidth: max(2, r.width * 0.045))
        context.stroke(curve(r, from: (0.72, 0.4), c1: (0.84, 0.24), c2: (0.91, 0.27), to: (0.94, 0.16)), with: .color(palette.fin), lineWidth: max(2, r.width * 0.045))
        context.fill(Path(ellipseIn: rect(r, x: 0.44, y: 0.3, w: 0.045, h: 0.045)), with: .color(palette.eye))
        context.fill(Path(ellipseIn: rect(r, x: 0.53, y: 0.3, w: 0.045, h: 0.045)), with: .color(palette.eye))
    }

    private static func drawTurtle(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(Path(ellipseIn: rect(r, x: 0.2, y: 0.24, w: 0.5, h: 0.48)), with: .color(palette.fin))
        context.fill(Path(ellipseIn: rect(r, x: 0.71, y: 0.38, w: 0.17, h: 0.18)), with: .color(palette.body))
        context.fill(Path(ellipseIn: rect(r, x: 0.26, y: 0.28, w: 0.42, h: 0.4)), with: .color(palette.accent))
        context.stroke(Path(ellipseIn: rect(r, x: 0.32, y: 0.34, w: 0.3, h: 0.28)), with: .color(palette.fin.opacity(0.55)), lineWidth: max(1, r.width * 0.025))
        context.fill(Path(ellipseIn: rect(r, x: 0.78, y: 0.43, w: 0.04, h: 0.04)), with: .color(palette.eye))
    }

    private static func drawSquid(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        let mantle = Path { p in
            p.move(to: point(r, 0.5, 0.12))
            p.addLine(to: point(r, 0.75, 0.5))
            p.addQuadCurve(to: point(r, 0.5, 0.74), control: point(r, 0.68, 0.76))
            p.addQuadCurve(to: point(r, 0.25, 0.5), control: point(r, 0.32, 0.76))
            p.closeSubpath()
        }
        context.fill(mantle, with: .color(palette.body))
        drawTentacles(in: r, context: &context, palette: palette, startY: 0.66, count: 6)
        context.fill(Path(ellipseIn: rect(r, x: 0.43, y: 0.42, w: 0.045, h: 0.045)), with: .color(palette.eye))
        context.fill(Path(ellipseIn: rect(r, x: 0.53, y: 0.42, w: 0.045, h: 0.045)), with: .color(palette.eye))
    }

    private static func drawOctopus(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(Path(ellipseIn: rect(r, x: 0.28, y: 0.16, w: 0.44, h: 0.46)), with: .color(palette.body))
        drawTentacles(in: r, context: &context, palette: palette, startY: 0.55, count: 8)
        context.fill(Path(ellipseIn: rect(r, x: 0.42, y: 0.34, w: 0.05, h: 0.05)), with: .color(palette.eye))
        context.fill(Path(ellipseIn: rect(r, x: 0.54, y: 0.34, w: 0.05, h: 0.05)), with: .color(palette.eye))
    }

    private static func drawLobster(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        drawShrimp(in: r, context: &context, palette: palette)
        context.fill(Path(ellipseIn: rect(r, x: 0.8, y: 0.18, w: 0.16, h: 0.12)), with: .color(palette.fin))
        context.fill(Path(ellipseIn: rect(r, x: 0.8, y: 0.7, w: 0.16, h: 0.12)), with: .color(palette.fin))
    }

    private static func drawJellyfish(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(Path(ellipseIn: rect(r, x: 0.26, y: 0.16, w: 0.48, h: 0.34)), with: .color(palette.body.opacity(0.72)))
        context.fill(Path(roundedRect: rect(r, x: 0.28, y: 0.36, w: 0.44, h: 0.18), cornerRadius: r.width * 0.08), with: .color(palette.belly.opacity(0.45)))
        for x in stride(from: 0.34, through: 0.66, by: 0.08) {
            context.stroke(curve(r, from: (x, 0.48), c1: (x - 0.05, 0.62), c2: (x + 0.05, 0.72), to: (x, 0.88)), with: .color(palette.fin.opacity(0.72)), lineWidth: max(1, r.width * 0.02))
        }
    }

    private static func drawSeal(in r: CGRect, context: inout GraphicsContext, palette: Palette) {
        context.fill(Path(ellipseIn: rect(r, x: 0.18, y: 0.27, w: 0.58, h: 0.38)), with: .color(palette.body))
        context.fill(Path(ellipseIn: rect(r, x: 0.66, y: 0.28, w: 0.22, h: 0.22)), with: .color(palette.body))
        context.fill(tail(r, x: 0.08, y: 0.5, w: 0.18, h: 0.3), with: .color(palette.fin))
        context.fill(Path(ellipseIn: rect(r, x: 0.36, y: 0.48, w: 0.26, h: 0.1)), with: .color(palette.belly))
        context.fill(Path(ellipseIn: rect(r, x: 0.78, y: 0.37, w: 0.045, h: 0.045)), with: .color(palette.eye))
    }

    private static func drawTentacles(in r: CGRect, context: inout GraphicsContext, palette: Palette, startY: CGFloat, count: Int) {
        for index in 0..<count {
            let t = CGFloat(index) / CGFloat(max(1, count - 1))
            let x = 0.32 + t * 0.36
            let endX = x + (index.isMultiple(of: 2) ? -0.04 : 0.04)
            context.stroke(curve(r, from: (x, startY), c1: (x - 0.04, startY + 0.12), c2: (endX + 0.04, startY + 0.2), to: (endX, 0.88)), with: .color(palette.fin), style: StrokeStyle(lineWidth: max(2, r.width * 0.035), lineCap: .round))
        }
    }

    private static func oval(_ r: CGRect, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        Path(ellipseIn: rect(r, x: x, y: y, w: w, h: h))
    }

    private static func tail(_ r: CGRect, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> Path {
        Path { p in
            p.move(to: point(r, x + w, y))
            p.addLine(to: point(r, x, y - h / 2))
            p.addLine(to: point(r, x, y + h / 2))
            p.closeSubpath()
        }
    }

    private static func fin(_ r: CGRect, top: Bool) -> Path {
        Path { p in
            p.move(to: point(r, 0.45, top ? 0.34 : 0.64))
            p.addQuadCurve(to: point(r, 0.57, top ? 0.35 : 0.62), control: point(r, 0.5, top ? 0.18 : 0.82))
            p.addLine(to: point(r, 0.5, top ? 0.45 : 0.55))
            p.closeSubpath()
        }
    }

    private static func dorsalFin(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: point(r, 0.46, 0.3))
            p.addLine(to: point(r, 0.56, 0.06))
            p.addLine(to: point(r, 0.64, 0.33))
            p.closeSubpath()
        }
    }

    private static func pectoralFin(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: point(r, 0.47, 0.55))
            p.addQuadCurve(to: point(r, 0.58, 0.75), control: point(r, 0.52, 0.78))
            p.addLine(to: point(r, 0.59, 0.52))
            p.closeSubpath()
        }
    }

    private static func belly(_ r: CGRect) -> Path {
        Path { p in
            p.move(to: point(r, 0.34, 0.56))
            p.addCurve(to: point(r, 0.74, 0.56), control1: point(r, 0.48, 0.72), control2: point(r, 0.66, 0.67))
            p.addCurve(to: point(r, 0.34, 0.56), control1: point(r, 0.62, 0.62), control2: point(r, 0.46, 0.63))
            p.closeSubpath()
        }
    }

    private static func stripe(_ r: CGRect, y: CGFloat) -> Path {
        Path { p in
            p.move(to: point(r, 0.33, y))
            p.addQuadCurve(to: point(r, 0.62, y - 0.02), control: point(r, 0.48, y + 0.08))
        }
    }

    private static func curve(_ r: CGRect, from: (CGFloat, CGFloat), c1: (CGFloat, CGFloat), c2: (CGFloat, CGFloat), to: (CGFloat, CGFloat)) -> Path {
        Path { p in
            p.move(to: point(r, from.0, from.1))
            p.addCurve(to: point(r, to.0, to.1), control1: point(r, c1.0, c1.1), control2: point(r, c2.0, c2.1))
        }
    }

    private static func rect(_ r: CGRect, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
        CGRect(x: r.minX + r.width * x, y: r.minY + r.height * y, width: r.width * w, height: r.height * h)
    }

    private static func point(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
    }
}
