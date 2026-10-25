import ServiceManagement
import SwiftUI
import TVKit

struct SettingsView: View {
    @Environment(RemoteModel.self) private var model
    @State private var hostDraft = ""
    @State private var macDraft = ""
    @State private var philipsDraft = ""
    @State private var philipsError: String?
    @State private var checkingPhilips = false
    @State private var appIDDraft = ""
    @State private var addError: String?
    @State private var searching = false
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            tvSection
            philipsSection
            remapSection
            appsSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            hostDraft = model.config.host ?? ""
            macDraft = model.config.wifiMAC ?? ""
            philipsDraft = model.config.philipsHost ?? ""
        }
    }

    private var philipsSection: some View {
        Section {
            HStack {
                TextField("Endereço", text: $philipsDraft, prompt: Text("192.168.1.30"))
                Button(checkingPhilips ? "Verificando…" : "Salvar") {
                    checkingPhilips = true
                    Task {
                        philipsError = await model.setPhilipsHost(philipsDraft)
                        checkingPhilips = false
                    }
                }
                .disabled(checkingPhilips || philipsDraft == (model.config.philipsHost ?? ""))
            }
            if let philipsError {
                Text(philipsError).foregroundStyle(.red).font(.callout)
            }
        } header: {
            Text("Philips TV")
        } footer: {
            footer(
                "Uma Philips NetTV anterior à Android TV (JointSPACE na porta 1925). Depois de salva, o controle mostra um seletor para trocar de TV. Apague o endereço para removê-la."
            )
        }
    }

    private var tvSection: some View {
        Section("Samsung TV") {
            LabeledContent("Nome", value: model.displayName)
            if let modelName = model.device?.modelName ?? model.config.modelName {
                LabeledContent("Modelo", value: modelName)
            }
            HStack {
                TextField("Endereço", text: $hostDraft, prompt: Text("192.168.1.20"))
                Button("Conectar") { model.useTV(host: hostDraft) }
                    .disabled(hostDraft.isEmpty || hostDraft == model.config.host)
            }
            HStack {
                Button(searching ? "Procurando…" : "Procurar TVs nesta rede") {
                    searching = true
                    Task {
                        await model.discover(autoSelect: false)
                        searching = false
                    }
                }
                .disabled(searching)
                Spacer()
                Button("Parear de novo", action: model.pairAgain)
            }
            ForEach(model.discovered) { tv in
                HStack {
                    VStack(alignment: .leading) {
                        Text(tv.name)
                        Text("\(tv.modelName) · \(tv.host)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if tv.host == model.config.host {
                        Text("Em uso").foregroundStyle(.secondary)
                    } else {
                        Button("Usar") {
                            hostDraft = tv.host
                            model.useTV(host: tv.host)
                        }
                    }
                }
            }
            TextField("Wi-Fi MAC", text: $macDraft, prompt: Text("Lido da TV"))
                .onSubmit { model.setWifiMAC(macDraft) }
                .help("Usado para ligar a TV pela rede (Wake-on-LAN).")
        }
    }

    private var remapSection: some View {
        let apps = model.config.knownApps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return Section {
            ForEach(model.config.remaps) { rule in
                HStack(spacing: 8) {
                    Picker(
                        "Quando",
                        selection: Binding(
                            get: { rule.fromAppID },
                            set: { model.updateRemap(rule.id, from: $0) }
                        )
                    ) {
                        ForEach(apps) { Text($0.name).tag($0.id) }
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    Picker(
                        "Abrir no lugar",
                        selection: Binding(
                            get: { rule.toAppID },
                            set: { model.updateRemap(rule.id, to: $0) }
                        )
                    ) {
                        ForEach(apps.filter { $0.id != rule.fromAppID }) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    Button {
                        model.removeRemap(rule.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remover esta regra")
                }
            }
            Button("Adicionar regra", action: model.addRemap)
                .disabled(apps.count < 2)
        } header: {
            Text("Botões do controle")
        } footer: {
            footer(
                "Reaproveite um botão de app do controle da TV: quando o app da esquerda abrir, o da direita abre no lugar. Funciona com o Controle TV aberto."
            )
        }
    }

    private var appsSection: some View {
        Section {
            HStack {
                TextField("ID do app", text: $appIDDraft, prompt: Text("3201907018807"))
                Button("Adicionar") {
                    Task {
                        addError = await model.addApp(id: appIDDraft)
                        if addError == nil { appIDDraft = "" }
                    }
                }
                .disabled(appIDDraft.isEmpty)
            }
            if let addError {
                Text(addError).foregroundStyle(.red).font(.callout)
            }
            ForEach(model.hiddenApps) { app in
                HStack {
                    Text(app.name)
                    Spacer()
                    Button("Mostrar") { model.unhide(app) }
                }
            }
            HStack {
                Button(model.scanningApps ? "Procurando…" : "Procurar apps de novo") {
                    Task { await model.rescanApps() }
                }
                .disabled(model.scanningApps)
                Spacer()
                Button("Restaurar ordem", action: model.resetOrder)
                    .disabled(model.config.appOrder.isEmpty)
            }
        } header: {
            Text("Apps")
        } footer: {
            footer("Adicione pelo ID um app que a busca não encontrou. Os apps ocultos aparecem aqui.")
        }
    }

    private var generalSection: some View {
        Section("Geral") {
            Toggle("Abrir ao iniciar sessão", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError {
                Text(loginError).foregroundStyle(.red).font(.callout)
            }
            LabeledContent("Arquivo de ajustes") {
                Button(ConfigStore.fileURL.lastPathComponent) {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
                }
                .buttonStyle(.link)
            }
        }
    }

    /// Section footer: secondary, left-aligned (grouped forms otherwise right-align wrapped footer text).
    private func footer(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
