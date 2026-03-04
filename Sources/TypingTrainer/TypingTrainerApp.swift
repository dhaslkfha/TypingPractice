import SwiftUI
import AppKit

@main
struct TypingTrainerApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @StateObject private var game = TypingGameViewModel()
    @AppStorage("colorMode") private var colorMode: ColorMode = .system

    private static let keyboardRows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            topPanel
            Divider()
            keyboardPanel
        }
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(colorMode.preferredScheme)
        .onAppear {
            applyAppearance(colorMode)
        }
        .onChange(of: colorMode) { newValue in
            applyAppearance(newValue)
        }
        .overlay(alignment: .top) {
            HStack {
                Picker("外观", selection: $colorMode) {
                    Image(systemName: "circle.lefthalf.filled").tag(ColorMode.system)
                    Image(systemName: "sun.max").tag(ColorMode.light)
                    Image(systemName: "moon").tag(ColorMode.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 160)

                Spacer()

                Button {
                    game.toggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .overlay {
            KeyboardInputView(onCharacter: game.handleInput)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
        .overlay {
            ConfettiView(trigger: game.confettiTrigger)
                .allowsHitTesting(false)
        }
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
            game.startIdleMonitor()
        }
        .onDisappear {
            game.stopIdleMonitor()
        }
    }

    private func applyAppearance(_ mode: ColorMode) {
        let appearance = mode.appearance
        NSApplication.shared.appearance = appearance
        NSApplication.shared.windows.forEach { $0.appearance = appearance }
    }

    private var feedbackColor: Color {
        switch game.feedback {
        case .correct:
            return .green
        case .wrong:
            return .red
        case .none:
            return .primary
        }
    }

    private var topPanel: some View {
        VStack(spacing: 24) {
            Text("当前目标字母")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                Text(game.currentTarget)
                    .font(.system(size: 220, weight: .heavy, design: .rounded))
                    .foregroundStyle(feedbackColor)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, y: 3)
                    .modifier(ShakeEffect(trigger: game.shakeTrigger))
                    .animation(.easeInOut(duration: 0.2), value: game.feedback)
                    .animation(.default, value: game.shakeTrigger)

                Text("得分 \(game.score)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 20)
    }

    private var keyboardPanel: some View {
        VStack(spacing: 18) {
            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 24
                let availableWidth = max(1, proxy.size.width - horizontalPadding * 2)
                let spacing: CGFloat = 10
                let rowSpacing: CGFloat = 12
                let maxKeys = Self.keyboardRows.map { $0.count }.max() ?? 1
                let keyWidth = (availableWidth - spacing * CGFloat(maxKeys - 1)) / CGFloat(maxKeys)
                let keyHeight = max(44, keyWidth * 0.85)
                let keyFontSize = max(18, keyHeight * 0.45)
                let totalHeight = keyHeight * CGFloat(Self.keyboardRows.count) + rowSpacing * CGFloat(Self.keyboardRows.count - 1) + 48

                VStack(spacing: rowSpacing) {
                    ForEach(Array(Self.keyboardRows.enumerated()), id: \.offset) { rowIndex, row in
                        let rowOffset = (CGFloat(maxKeys - row.count) * (keyWidth + spacing)) / 2
                        let extraShift = rowIndex == 2 ? -(keyWidth + spacing) / 2 : 0

                        HStack(spacing: spacing) {
                            Spacer().frame(width: rowOffset)

                            ForEach(row, id: \.self) { key in
                                KeycapView(
                                    title: key,
                                    isTarget: game.currentTarget == key,
                                    isHinting: game.showHint,
                                    width: keyWidth,
                                    height: keyHeight,
                                    fontSize: keyFontSize
                                )
                                .onTapGesture {
                                    game.handleInput(key)
                                }
                            }

                            Spacer().frame(width: rowOffset)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(x: extraShift)
                    }
                }
                .frame(width: availableWidth)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
                .frame(height: totalHeight)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
        .padding(.bottom, 24)
    }
}

private enum ColorMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            return "跟随系统"
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var preferredScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

enum InputFeedback {
    case none
    case correct
    case wrong
}

final class TypingGameViewModel: ObservableObject {
    @Published var currentTarget: String = TypingGameViewModel.randomLetter()
    @Published var score: Int = 0
    @Published var showHint: Bool = false
    @Published var feedback: InputFeedback = .none
    @Published var shakeTrigger: Int = 0
    @Published var confettiTrigger: Int = 0

    private var idleTimer: Timer?
    private var feedbackWorkItem: DispatchWorkItem?

    func handleInput(_ raw: String) {
        let input = raw.uppercased()
        guard input.count == 1 else { return }
        guard input.rangeOfCharacter(from: CharacterSet.letters.inverted) == nil else { return }

        feedbackWorkItem?.cancel()

        if input == currentTarget {
            score += 1
            feedback = .correct
            if score % 10 == 0 {
                confettiTrigger += 1
            }
        } else {
            feedback = .wrong
            shakeTrigger += 1
        }

        showHint = false
        restartIdleMonitor()

        let workItem = DispatchWorkItem { [weak self] in
            self?.currentTarget = Self.randomLetter()
            self?.feedback = .none
        }
        feedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    func startIdleMonitor() {
        restartIdleMonitor()
    }

    func stopIdleMonitor() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    func toggleFullscreen() {
        (NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first)?.toggleFullScreen(nil)
    }

    private func restartIdleMonitor() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.showHint = true
        }
    }

    private static func randomLetter() -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String(letters.randomElement() ?? "A")
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let size: CGFloat
    let rotation: Angle
    let color: Color
    let delay: Double
    let duration: Double
    let horizontalDrift: CGFloat
}

struct ConfettiView: View {
    let trigger: Int

    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.4)
                        .position(x: piece.x, y: animate ? proxy.size.height + 80 : -80)
                        .offset(x: animate ? piece.horizontalDrift : 0)
                        .rotationEffect(animate ? piece.rotation + Angle.degrees(180) : piece.rotation)
                        .animation(
                            .linear(duration: piece.duration).delay(piece.delay),
                            value: animate
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                start(size: proxy.size)
            }
            .onChange(of: trigger) { _ in
                start(size: proxy.size)
            }
        }
    }

    private func start(size: CGSize) {
        pieces = Self.makePieces(count: 140, width: size.width)
        isVisible = true
        animate = false
        DispatchQueue.main.async {
            animate = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                isVisible = false
            }
        }
    }

    private static func makePieces(count: Int, width: CGFloat) -> [ConfettiPiece] {
        let palette: [Color] = [.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink]
        return (0..<count).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...max(1, width)),
                size: CGFloat.random(in: 6...12),
                rotation: .degrees(Double.random(in: 0...180)),
                color: palette.randomElement() ?? .yellow,
                delay: Double.random(in: 0...0.6),
                duration: Double.random(in: 1.6...2.4),
                horizontalDrift: CGFloat.random(in: -80...80)
            )
        }
    }
}

struct ShakeEffect: GeometryEffect {
    var trigger: Int

    var animatableData: CGFloat {
        get { CGFloat(trigger) }
        set { }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 10 * sin(animatableData * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct KeycapView: View {
    let title: String
    let isTarget: Bool
    let isHinting: Bool
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shouldHighlight = isTarget && isHinting
        let baseFill = colorScheme == .dark ? Color(nsColor: .controlColor) : Color(nsColor: .controlBackgroundColor)
        let strokeColor = colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.18)

        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(shouldHighlight ? Color(red: 1.0, green: 0.93, blue: 0.35) : baseFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear)
                )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    shouldHighlight
                    ? Color(red: 0.84, green: 0.57, blue: 0.02)
                    : strokeColor,
                    lineWidth: shouldHighlight ? 2 : 0.8
                )

            Text(title)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(shouldHighlight ? Color(red: 0.28, green: 0.20, blue: 0.00) : Color.primary)
        }
        .frame(width: width, height: height)
        .shadow(
            color: shouldHighlight ? Color.orange.opacity(0.45) : Color.black.opacity(0.12),
            radius: shouldHighlight ? 10 : 3,
            y: shouldHighlight ? 4 : 2
        )
        .animation(.easeInOut(duration: 0.2), value: shouldHighlight)
    }
}

struct KeyboardInputView: NSViewRepresentable {
    let onCharacter: (String) -> Void

    func makeNSView(context: Context) -> InputCaptureView {
        let view = InputCaptureView()
        view.onCharacter = onCharacter
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: InputCaptureView, context: Context) {
        nsView.onCharacter = onCharacter
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class InputCaptureView: NSView {
    var onCharacter: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onCharacter?(event.charactersIgnoringModifiers ?? "")
    }
}
