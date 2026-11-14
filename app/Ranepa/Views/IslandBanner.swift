import SwiftUI

/// Где Dynamic Island: баннер «вытекает» из него. Система его координат
/// не отдаёт; размеры сняты со снимков симуляторов.
enum Island {
    static let height: CGFloat = 37

    /// Код модели: `iPhone18,1`; в симуляторе — модель симулятора.
    static let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? SupportLink.machineIdentifier

    /// iPhone 14 Pro и новее, кроме моделей с вырезом (16e, 17e) и iPhone Duo
    /// с камерой в углу. iPad и Mac — без острова.
    static var available: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && !ProcessInfo.processInfo.isiOSAppOnMac && hasIsland(model)
    }

    static func hasIsland(_ identifier: String) -> Bool {
        guard let major = major(identifier) else { return false }
        return major >= 15 && !["iPhone17,5", "iPhone18,5", "iPhone19,4"].contains(identifier)
    }

    /// Остров на экране шириной [width]: у iPhone 18 Pro он уже, у Air — ниже.
    static func frame(width: CGFloat, model: String = model) -> CGRect {
        let w: CGFloat = (major(model) ?? 0) >= 19 ? 95 : 126
        let top: CGFloat = model == "iPhone18,4" ? 20 : 14
        return CGRect(x: (width - w) / 2, y: top, width: w, height: height)
    }

    private static func major(_ identifier: String) -> Int? {
        guard identifier.hasPrefix("iPhone") else { return nil }
        return Int(identifier.dropFirst(6).prefix { $0 != "," })
    }
}

/// Баннер внутри приложения, который вытекает из Dynamic Island: капля на
/// «шейке» раздувается в карточку, потом проявляется текст. Свайп вверх
/// или нажатие — втягивается обратно. Подход из expo-dynamic-notifications.
struct IslandBanner: View {
    /// Что показать; nil — убрать. Новый баннер сменяет старый через остров.
    let banner: Banner?
    let dismiss: () -> Void

    @State private var shown: Banner?
    @State private var drop: CGFloat = 0
    @State private var expand: CGFloat = 0
    @State private var reveal: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var cardHeight: CGFloat = 74
    /// Номер показа: завершение старой анимации не трогает новый баннер.
    @State private var generation = 0

    var body: some View {
        GeometryReader { g in
            let card = cardFrame(width: g.size.width)
            ZStack(alignment: .topLeading) {
                if shown != nil {
                    Goo(drop: drop, expand: expand, card: card, dragY: dragY, width: g.size.width)
                        .allowsHitTesting(false)
                }
                if let shown {
                    content(shown)
                        .frame(width: card.width)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = max($0, 74) }
                        .opacity(reveal)
                        .blur(radius: (1 - reveal) * 8)
                        .scaleEffect(0.88 + 0.12 * reveal)
                        .contentShape(.rect(cornerRadius: 37))
                        .onTapGesture(perform: dismiss)
                        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
                            .onChanged { dragY = min(max($0.translation.height, -120), 24) }
                            .onEnded { v in
                                if dragY < -18 || v.predictedEndTranslation.height < -60 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(duration: 0.56, bounce: 0.3)) { dragY = 0 }
                                }
                            })
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Закрыть", dismiss)
                        .offset(x: card.minX, y: card.minY + dragY)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: banner, initial: true) { _, next in update(next) }
    }

    private func cardFrame(width: CGFloat) -> CGRect {
        let w = min(width - 32, 396)
        return CGRect(x: (width - w) / 2, y: Island.frame(width: width).maxY + 34, width: w, height: cardHeight)
    }

    private func content(_ banner: Banner) -> some View {
        HStack(spacing: 12) {
            Image(systemName: banner.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title).font(.subheadline.weight(.semibold))
                Text(banner.message).font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 22)
        .padding(.vertical, 14)
    }

    private func update(_ next: Banner?) {
        guard next != shown else { return }
        if shown == nil {
            if let next { enter(next) }
        } else {
            exit { if let banner { enter(banner) } }
        }
    }

    private func enter(_ banner: Banner) {
        generation += 1
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            shown = banner
            drop = 0; expand = 0; reveal = 0; dragY = 0
        }
        withAnimation(.spring(duration: 1.15, bounce: 0.18)) { drop = 1 }
        withAnimation(.spring(duration: 1.0, bounce: 0.2).delay(0.34)) { expand = 1 }
        withAnimation(.spring(duration: 0.7, bounce: 0).delay(0.56)) { reveal = 1 }
    }

    private func exit(then next: @escaping () -> Void) {
        let current = generation
        withAnimation(.spring(duration: 0.36, bounce: 0)) { reveal = 0 }
        withAnimation(.spring(duration: 0.66, bounce: 0.08).delay(0.1)) { expand = 0; dragY = 0 }
        withAnimation(.spring(duration: 1.15, bounce: 0.1).delay(0.28), completionCriteria: .logicallyComplete) {
            drop = 0
        } completion: {
            guard current == generation else { return }
            shown = nil
            next()
        }
    }
}

/// Остров, шейка и капля одним «жидким» слоем: размытие и порог по
/// прозрачности сливают фигуры, пока они рядом.
private struct Goo: View, Animatable {
    var drop: CGFloat
    var expand: CGFloat
    let card: CGRect
    let dragY: CGFloat
    let width: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(drop, expand) }
        set { drop = newValue.first; expand = newValue.second }
    }

    var body: some View {
        Canvas { ctx, _ in
            let g = GooGeometry(drop: drop, expand: expand, card: card.offsetBy(dx: 0, dy: dragY), width: width)
            ctx.addFilter(.alphaThreshold(min: 0.43, color: .black))
            ctx.addFilter(.blur(radius: 14))
            ctx.drawLayer { layer in
                let inset: CGFloat = 14 * 0.26
                let island = g.island.insetBy(dx: inset, dy: inset)
                layer.fill(Path(roundedRect: island, cornerRadius: island.height / 2), with: .color(.black))
                layer.fill(Path(roundedRect: g.neck, cornerRadius: g.neck.width / 2), with: .color(.black))
                layer.fill(Path(roundedRect: g.body, cornerRadius: g.radius), with: .color(.black))
            }
        }
    }
}

/// Форма капли на каждом шаге: растёт и вытягивается, пока висит на
/// шейке, потом раздувается в карточку. Числа — из expo-dynamic-notifications.
struct GooGeometry {
    let island: CGRect
    let body: CGRect
    let radius: CGFloat
    let neck: CGRect

    init(drop: CGFloat, expand: CGFloat, card: CGRect, width: CGFloat) {
        island = Island.frame(width: width)
        let islandBottom = island.maxY
        let grow = 1 - pow(1 - min(max(drop / 0.7, 0), 1), 1.25)
        let neckness = Self.neckProfile(drop / 0.82)
        let stretch = 1 + 0.38 * neckness
        let droplet = 52 * grow

        let w = min(Self.mix(expand, droplet / stretch, card.width), width - 20)
        let h = Self.mix(expand, droplet * stretch, card.height)
        radius = min(Self.mix(expand, droplet / 2, min(card.height / 2, 37)), min(w, h) / 2)
        let centerY = Self.mix(drop, islandBottom - Island.height * 0.34, card.midY)
        body = CGRect(x: width / 2 - w / 2, y: centerY - h / 2, width: w, height: h)

        let neckWidth = min(60, w) * neckness
        let neckY = islandBottom - Island.height / 2
        neck = CGRect(x: width / 2 - neckWidth / 2, y: neckY, width: neckWidth, height: max(centerY - neckY, 0))
    }

    static func mix(_ t: CGFloat, _ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * t }

    /// Толщина шейки: растёт, достигает пика и рвётся к концу падения.
    static func neckProfile(_ progress: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        guard t > 0, t < 1 else { return 0 }
        let rise: CGFloat = 1.6, fall: CGFloat = 1.4
        let peak = rise / (rise + fall)
        let normal = pow(peak, rise) * pow(1 - peak, fall)
        return pow(t, rise) * pow(1 - t, fall) / normal
    }
}
