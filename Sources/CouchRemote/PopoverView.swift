import SwiftUI
import TVKit

/// The menu bar popover: status, apps (or inputs on the Philips set), remote, volume, then typing.
struct PopoverView: View {
    @Environment(RemoteModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            HeaderView()
            if model.config.philipsHost != nil {
                TVPicker()
            }
            StatusBanner()
            if model.isPhilips {
                SourcesSection()
            } else {
                AppsSection()
            }
            RemoteSection()
            VolumeRow()
            if !model.isPhilips {
                FooterRow()
            }
        }
        .padding(14)
        .frame(width: 340)
        .hintBubbles()
        .background(
            WindowVisibilityReader { window, visible in
                model.setPopover(window: window, visible: visible)
            })
    }
}

// MARK: - Header

private struct HeaderView: View {
    @Environment(RemoteModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tv")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .glassSurface(in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(model.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button(action: model.hideRemote) {
                Image(systemName: "minus")
            }
            .buttonStyle(GlassCircleButtonStyle(diameter: 30))
            .hint("Esconder o controle (Esc). O app continua na barra de menu.")

            Menu {
                if !model.isPhilips {
                    Button("Atualizar apps") { Task { await model.rescanApps() } }
                    Button("Parear de novo") { model.pairAgain() }
                    Divider()
                }
                Button("Ajustes…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Button("Sair do Controle TV") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(GlassCircleButtonStyle(diameter: 30))
            .fixedSize()
            .hint("Mais opções")

            Button(action: model.togglePower) {
                Image(systemName: "power")
            }
            .buttonStyle(GlassCircleButtonStyle(diameter: 30, tint: .red))
            .disabled(!model.canTogglePower)
            .hint(powerHelp)
        }
        .background(WindowDragArea())
    }

    private var powerHelp: String {
        if !model.canTogglePower { return "Esta Philips não liga pela rede" }
        return model.power == .on ? "Desligar" : "Ligar"
    }

    private var statusText: String {
        switch model.link {
        case .noTV: return "Nenhuma TV selecionada"
        case .searching: return "Procurando TVs…"
        case .waitingForApproval: return "Aguardando permissão na TV"
        case .connecting where model.power == .on: return "Conectando…"
        case .failed: return "Não conectada"
        default: break
        }
        switch model.power {
        case .on: return ["Ligada", model.frontAppName].compactMap { $0 }.joined(separator: " · ")
        case .standby: return "Em espera"
        case .offline: return "Desligada ou fora da rede"
        case .unknown: return "Verificando…"
        }
    }

    private var statusColor: Color {
        switch model.link {
        case .waitingForApproval, .connecting, .searching: return .orange
        case .failed: return .red
        default: break
        }
        return model.power == .on ? .green : .secondary.opacity(0.5)
    }
}

// MARK: - TV picker

private struct TVPicker: View {
    @Environment(RemoteModel.self) private var model

    var body: some View {
        Picker("TV", selection: Binding(get: { model.config.activeTV }, set: model.selectTV)) {
            Text(model.samsungName).tag(TVBrand.samsung)
            Text("Philips").tag(TVBrand.philips)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .hint("Escolha qual TV este controle comanda")
    }
}

// MARK: - Banner

private struct StatusBanner: View {
    @Environment(RemoteModel.self) private var model

    var body: some View {
        switch model.link {
        case .waitingForApproval:
            banner(
                symbol: "hand.tap", title: "Toque em Permitir na TV",
                detail: "A TV está perguntando se o Controle TV pode controlá-la.")
        case .failed(let message):
            banner(
                symbol: "exclamationmark.triangle", title: "Não foi possível controlar a TV", detail: message,
                action: ("Parear de novo", model.pairAgain))
        case .noTV:
            banner(
                symbol: "magnifyingglass", title: "Nenhuma TV encontrada",
                detail: "Ligue a TV e confira se ela está no mesmo Wi-Fi deste Mac.",
                action: ("Procurar de novo", { Task { await model.discover(autoSelect: true) } }))
        case .offline where model.isPhilips:
            banner(
                symbol: "tv.slash", title: "\(model.displayName) desligada",
                detail: "Ligue a TV no controle físico — este modelo não liga pela rede.",
                action: model.config.host == nil
                    ? nil : ("Usar a \(model.samsungName)", { model.selectTV(.samsung) }))
        case .offline:
            banner(
                symbol: "tv.slash", title: "\(model.displayName) desligada",
                detail: "Ligue a TV, ou toque em Ligar para acordá-la pela rede.",
                action: ("Ligar", model.togglePower))
        default:
            EmptyView()
        }
    }

    private func banner(symbol: String, title: String, detail: String, action: (String, () -> Void)? = nil) -> some View
    {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.0, action: action.1)
                        .controlSize(.small)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .glassSurface(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Apps

private struct AppsSection: View {
    @Environment(RemoteModel.self) private var model
    /// App being dragged, so tiles can reorder live as it passes over them.
    @State private var dragging: String?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        let apps = model.apps
        let shown = model.showAllApps ? apps : Array(apps.prefix(10))

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Apps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if model.scanningApps {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                if apps.count > 10 {
                    Button(model.showAllApps ? "Menos" : "Todos (\(apps.count))") {
                        withAnimation(.snappy) { model.showAllApps.toggle() }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11, weight: .medium))
                }
            }
            .padding(.horizontal, 2)

            if model.showAllApps && apps.count > 10 {
                Text("Arraste os apps para reorganizar. Os dez primeiros aparecem com a lista recolhida.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 2)
            }

            if apps.isEmpty {
                Text(
                    model.scanningApps ? "Procurando apps na TV…" : "Os apps aparecem aqui quando a TV estiver ligada."
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(shown) { app in
                        AppTile(app: app, isDragging: dragging == app.id)
                            .onDrag {
                                dragging = app.id
                                return NSItemProvider(object: app.id as NSString)
                            } preview: {
                                AppIconView(app: app, icon: model.icons[app.id]).frame(width: 46, height: 46)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: ReorderDropDelegate(target: app.id, model: model, dragging: $dragging))
                    }
                }
                // Dropping between tiles still ends the drag.
                .onDrop(of: [.text], delegate: ReorderDropDelegate(target: nil, model: model, dragging: $dragging))
            }
        }
    }
}

/// The Philips set's inputs, in place of apps. The list is what the TV supports, not what is plugged in.
private struct SourcesSection: View {
    @Environment(RemoteModel.self) private var model
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entradas")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            if model.philipsSources.isEmpty {
                Text("As entradas aparecem aqui quando a TV estiver ligada.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(model.philipsSources) { source in
                        let current = model.currentSource == source.id
                        Button {
                            model.selectSource(source.id)
                        } label: {
                            Text(source.name)
                                .font(.system(size: 11, weight: current ? .semibold : .regular))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(current ? Color.accentColor : .primary)
                        .glassSurface(in: Capsule(), interactive: true)
                    }
                }
            }
        }
    }
}

/// Moves the dragged app into the hovered tile's place as soon as it enters, so the grid reorders live.
private struct ReorderDropDelegate: DropDelegate {
    let target: String?
    let model: RemoteModel
    @Binding var dragging: String?

    func dropEntered(info: DropInfo) {
        guard let dragging, let target, dragging != target else { return }
        withAnimation(.snappy(duration: 0.2)) { model.move(dragging, to: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

private struct AppTile: View {
    @Environment(RemoteModel.self) private var model
    let app: TVApp
    let isDragging: Bool
    @State private var hovering = false

    var body: some View {
        // A tap gesture rather than a Button: buttons swallow the mouse-down that starts a drag.
        VStack(spacing: 3) {
            AppIconView(app: app, icon: model.icons[app.id])
                .frame(width: 46, height: 46)
                .scaleEffect(hovering && !isDragging ? 1.06 : 1)
            Circle()
                .fill(.primary.opacity(model.runningApps.contains(app.id) ? 0.65 : 0))
                .frame(width: 4, height: 4)
            Text(shortName)
                .font(.system(size: 10))
                .foregroundStyle(model.frontAppID == app.id ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.35 : 1)
        .onTapGesture { model.launch(app) }
        .onHover { hovering = $0 }
        .animation(.snappy(duration: 0.15), value: hovering)
        .hint("\(app.name). Arraste para reorganizar.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.launch(app) }
        .contextMenu {
            Button("Mover para o início") { withAnimation(.snappy) { model.moveToFront(app) } }
            Button("Mover para o fim") { withAnimation(.snappy) { model.moveToEnd(app) } }
            Divider()
            Button("Ocultar") { withAnimation(.snappy) { model.hide(app) } }
        }
    }

    /// "Spotify - Music and Podcasts" → "Spotify", "Pluto TV: Free Movies & Shows" → "Pluto TV".
    private var shortName: String {
        String(app.name.split(whereSeparator: { $0 == ":" || $0 == "-" }).first ?? Substring(app.name))
            .trimmingCharacters(in: .whitespaces)
    }
}

struct AppIconView: View {
    let app: TVApp
    let icon: AppIcon?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        let brand = AppCatalog.brand(for: app.name)
        let background = brand.map { Color(hex: $0.color) } ?? fallbackColor

        ZStack {
            shape.fill(background.gradient)
            if let icon {
                Image(nsImage: icon.image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: icon.fillsTile ? .fill : .fit)
                    .padding(icon.fillsTile ? 0 : 9)
            } else if let symbol = brand?.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Text(String(app.name.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1.5)
    }

    /// Stable colour per name (String.hashValue changes between launches).
    private var fallbackColor: Color {
        let hash = app.name.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        return Color(hue: Double(hash % 360) / 360, saturation: 0.55, brightness: 0.7)
    }
}

// MARK: - Remote

private struct RemoteSection: View {
    @Environment(RemoteModel.self) private var model

    var body: some View {
        HStack {
            VStack(spacing: 14) {
                HoldCircle(key: .back, diameter: 40) { Image(systemName: "arrow.uturn.backward") }
                    .hint(model.isPhilips ? "Voltar (⌫)" : "Voltar (⌫). Segure para sair do app.")
                Button {
                    model.press(.home)
                } label: {
                    Image(systemName: "house")
                }
                .hint("Início (H)")
                // Opens the TV's own input list. KEY_HDMI1 and KEY_HDMI2 did nothing on this TV (tested); KEY_SOURCE works.
                Button {
                    model.press(.source)
                } label: {
                    Image(systemName: "cable.connector.horizontal")
                }
                .hint("Fonte: mostra as entradas da TV; escolha com as setas e OK")
            }
            Spacer()
            if model.pointerMode {
                TrackpadView(size: 168)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                DPad()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            Spacer()
            VStack(spacing: 14) {
                Button(action: model.playPause) { Image(systemName: "playpause.fill") }
                    .hint("Reproduzir / Pausar (espaço)")
                Button {
                    model.press(.info)
                } label: {
                    Image(systemName: "info")
                }
                .hint("Informações (I)")
                Button {
                    withAnimation(.snappy(duration: 0.2)) { model.pointerMode.toggle() }
                } label: {
                    Image(systemName: model.pointerMode ? "dpad" : "cursorarrow.rays")
                }
                .hint(
                    model.pointerMode
                        ? "Voltar para as setas" : "Trackpad: move o cursor da TV, por exemplo no navegador"
                )
                .opacity(model.isPhilips ? 0 : 1)
                .disabled(model.isPhilips)
            }
        }
        .buttonStyle(GlassCircleButtonStyle(diameter: 40))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
}

private struct DPad: View {
    @Environment(RemoteModel.self) private var model
    private let size: CGFloat = 168

    var body: some View {
        ZStack {
            Color.clear.glassSurface(in: Circle())
            arrow(.up, "chevron.up", "Cima (↑)").offset(y: -size / 2 + 26)
            arrow(.down, "chevron.down", "Baixo (↓)").offset(y: size / 2 - 26)
            arrow(.left, "chevron.left", "Esquerda (←)").offset(x: -size / 2 + 26)
            arrow(.right, "chevron.right", "Direita (→)").offset(x: size / 2 - 26)
            HoldCircle(key: .enter, diameter: 76) {
                Text("OK").font(.system(size: 13, weight: .semibold))
            }
            .hint("OK (↩)")
        }
        .frame(width: size, height: size)
    }

    /// Arrows are held, not clicked: keep the mouse down to keep moving (cursor, scrolling, seeking).
    private func arrow(_ key: RemoteKey, _ symbol: String, _ name: String) -> some View {
        let lit = model.isLit(key)
        return Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(lit ? Color.accentColor : .secondary)
            .background(Circle().fill(Color.accentColor.opacity(lit ? 0.16 : 0)).padding(4))
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.12), value: lit)
            .holdsKey(key)
            .hint(model.isPhilips ? name : "\(name). Segure para continuar movendo.")
    }
}

/// A round glass control that holds its key while the mouse is down, like a physical remote button.
private struct HoldCircle<Label: View>: View {
    @Environment(RemoteModel.self) private var model
    let key: RemoteKey
    let diameter: CGFloat
    @ViewBuilder let label: Label

    var body: some View {
        let lit = model.isLit(key)
        label
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .glassSurface(in: Circle(), interactive: true)
            .scaleEffect(lit ? 0.92 : 1)
            .animation(.snappy(duration: 0.15), value: lit)
            .holdsKey(key)
    }
}

private struct HoldsKey: ViewModifier {
    @Environment(RemoteModel.self) private var model
    let key: RemoteKey
    @State private var down = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !down else { return }
                        down = true
                        model.hold(key)
                    }
                    .onEnded { _ in
                        down = false
                        model.release(key)
                    }
            )
            .onDisappear {
                if down { model.release(key) }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.press(key) }
    }
}

extension View {
    /// Mouse down sends Press, mouse up sends Release. A quick click is a single press on the TV.
    fileprivate func holdsKey(_ key: RemoteKey) -> some View {
        modifier(HoldsKey(key: key))
    }
}

// MARK: - Volume

private struct VolumeRow: View {
    @Environment(RemoteModel.self) private var model

    var body: some View {
        HStack(spacing: 7) {
            Button(action: model.toggleMute) {
                Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .buttonStyle(GlassCircleButtonStyle(diameter: 30))
            .hint("Mudo (M)")

            Button {
                model.stepVolume(-1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(GlassCircleButtonStyle(diameter: 30))
            .hint("Abaixar volume (−)")

            Slider(value: Binding(get: { model.volume }, set: model.setVolume), in: 0...model.volumeMax)
                .controlSize(.small)
                .hint("Volume")

            Button {
                model.stepVolume(1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(GlassCircleButtonStyle(diameter: 30))
            .hint("Aumentar volume (+)")

            Text("\(Int(model.volume))")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            HStack(spacing: 0) {
                Button {
                    model.press(.channelDown)
                } label: {
                    Image(systemName: "chevron.down").frame(width: 26, height: 28)
                }
                .hint("Canal anterior")
                Text("CH").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Button {
                    model.press(.channelUp)
                } label: {
                    Image(systemName: "chevron.up").frame(width: 26, height: 28)
                }
                .hint("Próximo canal")
            }
            .font(.system(size: 11, weight: .bold))
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .glassSurface(in: Capsule(), interactive: true)
        }
    }
}

// MARK: - Footer

private struct FooterRow: View {
    @Environment(RemoteModel.self) private var model
    @State private var text = ""
    @State private var clearingAfterSubmit = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "keyboard").foregroundStyle(.secondary)
                TextField(model.tvKeyboardOpen ? "Teclado da TV aberto, digite aqui" : "Digitar na TV…", text: $text)
                    .textFieldStyle(.plain)
                    // Live: the TV's field mirrors this one as you type; Return confirms it.
                    .onChange(of: text) { _, value in
                        // Clearing after Return must not send "" and wipe the field just confirmed.
                        if clearingAfterSubmit {
                            clearingAfterSubmit = false
                        } else {
                            model.setTypedText(value)
                        }
                    }
                    .onSubmit {
                        model.submitTypedText()
                        clearingAfterSubmit = true
                        text = ""
                    }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.primary.opacity(0.06)))
            .hint("Digita ao vivo no campo de texto da TV. Abra uma busca na TV antes; Return confirma.")

        }
        .padding(.top, 10)
        .overlay(alignment: .top) { Divider() }
    }
}
