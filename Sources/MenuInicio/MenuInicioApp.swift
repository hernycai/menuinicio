import SwiftUI
import ServiceManagement
import Foundation

@main
struct MenuInicioApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Ajustes") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
        }
        Settings { SettingsView() }
    }
}

struct StartupItem: Identifiable {
    let id: String
    let name: String
    let path: URL
    let domain: String
    let label: String
    let kind: String
    let description: String
    let application: String
    let executablePath: String
    let developer: String
    let effect: String
    let manageable: Bool
    let isDisabled: Bool
}

@MainActor
final class StartupModel: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var search = ""
    @Published var selection = "Todo"
    @Published var notice = ""
    @Published var isLoading = false
    @Published var lastChangeAvailable = false
    private var lastChange: (item: StartupItem, wasDisabled: Bool)?
    @Published var filter = "Todo"

    var visibleItems: [StartupItem] {
        items.filter { item in
            (selection == "Todo" || item.kind == selection) &&
            (filter == "Todo" || (filter == "Modificables" ? item.manageable : !item.manageable)) &&
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || item.label.localizedCaseInsensitiveContains(search) || item.path.path.localizedCaseInsensitiveContains(search) || item.application.localizedCaseInsensitiveContains(search) || item.developer.localizedCaseInsensitiveContains(search))
        }
    }
    var activeCount: Int { items.filter { !$0.isDisabled }.count }
    var disabledCount: Int { items.filter(\.isDisabled).count }

    func refresh() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let found = Self.scan()
            await MainActor.run { self.items = found; self.isLoading = false }
        }
    }

    nonisolated private static func scan() -> [StartupItem] {
        let fm = FileManager.default
        let uid = getuid()
        let sources: [(URL, String, String, Bool)] = [
            (fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"), "Agente usuario", "gui/\(uid)", true),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), "Agente del sistema", "gui/\(uid)", true),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), "Daemon del sistema", "system", false)
        ]
        var disabledLabels: [String: Set<String>] = [:]
        for domain in Set(sources.map(\.2)) {
            let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["print-disabled", domain]
            let pipe = Pipe(); task.standardOutput = pipe; task.standardError = Pipe()
            if (try? task.run()) != nil {
                let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
                let output = String(decoding: data, as: UTF8.self)
                disabledLabels[domain] = Set(output.components(separatedBy: .newlines).compactMap { line in
                    guard line.contains("=> disabled") || line.contains("=> true"),
                          let first = line.firstIndex(of: "\""),
                          let last = line[line.index(after: first)...].firstIndex(of: "\"") else { return nil }
                    return String(line[line.index(after: first)..<last])
                })
            }
        }
        var result: [StartupItem] = []
        for (directory, kind, domain, manageable) in sources {
            guard let urls = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { continue }
            for original in urls where original.pathExtension == "plist" || original.lastPathComponent.hasSuffix(".plist.disabled") {
                let fileDisabled = original.lastPathComponent.hasSuffix(".disabled")
                let actual = fileDisabled ? URL(fileURLWithPath: String(original.path.dropLast(".disabled".count))) : original
                let data = try? Data(contentsOf: actual)
                let plist = data.flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) } as? [String: Any]
                let label = plist?["Label"] as? String ?? actual.deletingPathExtension().lastPathComponent
                let display = label.split(separator: ".").last.map(String.init) ?? label
                let program = (plist?["Program"] as? String) ?? ((plist?["ProgramArguments"] as? [String])?.first)
                let description = (plist?["Comment"] as? String) ?? (plist?["Description"] as? String) ?? program.map { "Inicia el proceso \($0) automáticamente." } ?? "Servicio en segundo plano registrado por \(label)."
                let executable = program ?? actual.path
                let appBundle = Self.appBundlePath(for: executable)
                let bundle = appBundle.flatMap { Bundle(path: $0) }
                let application = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? URL(fileURLWithPath: executable).deletingPathExtension().lastPathComponent
                let signedPath = appBundle ?? executable
                let developer = Self.signingAuthority(at: signedPath)
                let effect = kind == "Daemon del sistema" ? "Al apagarlo, el servicio deja de ejecutarse para todo el sistema. Puede afectar a otros usuarios o funciones de la app." : "Al apagarlo, \(application) deja de iniciarse en segundo plano. La sincronización, avisos o actualizaciones de esa app pueden dejar de funcionar."
                result.append(StartupItem(id: original.path, name: display, path: original, domain: domain, label: label, kind: kind, description: description, application: application, executablePath: executable, developer: developer, effect: effect, manageable: manageable, isDisabled: fileDisabled || (disabledLabels[domain]?.contains(label) ?? false)))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func appBundlePath(for executable: String) -> String? {
        var url = URL(fileURLWithPath: executable).standardizedFileURL
        while url.path != "/" {
            if url.pathExtension == "app" { return url.path }
            url.deleteLastPathComponent()
        }
        return nil
    }

    nonisolated private static func signingAuthority(at path: String) -> String {
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", "--verbose=2", "--", path]
        let pipe = Pipe(); task.standardError = pipe; task.standardOutput = Pipe()
        guard (try? task.run()) != nil else { return "No identificada" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        if let line = output.components(separatedBy: .newlines).first(where: { $0.hasPrefix("Authority=") }) { return String(line.dropFirst("Authority=".count)) }
        return "Sin firma identificada"
    }

    func toggle(_ item: StartupItem, enable: Bool) {
        performToggle(item, enable: enable, registerUndo: true)
    }

    func undoLastChange() {
        guard let change = lastChange else { return }
        performToggle(change.item, enable: change.wasDisabled, registerUndo: false)
        lastChange = nil
        lastChangeAvailable = false
    }

    private func performToggle(_ item: StartupItem, enable: Bool, registerUndo: Bool) {
        guard item.manageable else {
            notice = "Este elemento está en una ubicación protegida. Para modificarlo se necesita autorización de administrador."
            return
        }
        let target = "\(item.domain)/\(item.label)"
        let verb = enable ? "enable" : "disable"
        do {
            let task = Process()
            if item.domain == "system" {
                task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                let command = "/bin/launchctl \(verb) '\(target.replacingOccurrences(of: "'", with: "'\\''"))'"
                let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                task.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
            } else {
                task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                task.arguments = [verb, target]
            }
            let pipe = Pipe(); task.standardError = pipe; task.standardOutput = pipe
            try task.run(); task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                notice = item.domain == "system" ? "macOS canceló o rechazó el cambio de \(item.label)." : "macOS no pudo cambiar el estado de \(item.label)."
                return
            }
            if registerUndo {
                lastChange = (item, item.isDisabled)
                lastChangeAvailable = true
            }
            notice = enable ? "\(item.name) se habilitará al iniciar sesión." : "\(item.name) se deshabilitará al iniciar sesión."
            refresh()
        } catch { notice = "No se pudo ejecutar launchctl: \(error.localizedDescription)" }
    }
}

struct MainView: View {
    @StateObject private var model = StartupModel()
    @AppStorage("appearance") private var appearance = "dark"
    private let red = Color(red: 0.95, green: 0.19, blue: 0.22)
    private var isLight: Bool { appearance == "light" }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                header
                if !model.notice.isEmpty {
                    HStack { Image(systemName: "info.circle.fill"); Text(model.notice); Spacer(); if model.lastChangeAvailable { Button("Deshacer") { model.undoLastChange() }.buttonStyle(.bordered) }; Button { model.notice = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.82)).padding(12).background(red.opacity(0.13))
                }
                list
                footer
            }.background(isLight ? Color.white : Color(red: 0.09, green: 0.09, blue: 0.09))
        }
        .background(isLight ? Color(red: 0.95, green: 0.95, blue: 0.96) : Color(red: 0.09, green: 0.09, blue: 0.09))
        .foregroundStyle(isLight ? Color.black.opacity(0.86) : Color.white)
        .preferredColorScheme(isLight ? .light : .dark)
        .onAppear { model.refresh() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(spacing: 10) {
                Image(systemName: "power.circle.fill").font(.system(size: 31)).foregroundStyle(red)
                VStack(alignment: .leading, spacing: 1) { Text("ROJO").font(.system(size: 13, weight: .black, design: .rounded)).tracking(2); Text("INICIO").font(.system(size: 10, weight: .medium)).tracking(2).foregroundStyle(.secondary) }
            }.padding(.top, 6)
            VStack(alignment: .leading, spacing: 5) {
                Text("GESTIÓN").font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(.secondary).padding(.bottom, 5)
                ForEach(["Todo", "Agente usuario", "Agente del sistema", "Daemon del sistema"], id: \.self) { category in
                    Button { model.selection = category } label: {
                        HStack(spacing: 10) { Image(systemName: category == "Todo" ? "square.grid.2x2" : "gearshape.2").frame(width: 16); Text(category); Spacer(); if category == "Todo" { Text("\(model.items.count)").foregroundStyle(.secondary) } }
                            .font(.system(size: 12, weight: model.selection == category ? .semibold : .regular)).foregroundStyle(model.selection == category ? .white : .white.opacity(0.63)).padding(.vertical, 9).padding(.horizontal, 10).background(model.selection == category ? red.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Text("ESTADO DEL SISTEMA").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                metric("Activos", value: model.activeCount, tint: red)
                metric("Deshabilitados", value: model.disabledCount, tint: .white.opacity(0.65))
            }.padding(12).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
            HStack { Image(systemName: "circle.lefthalf.filled").foregroundStyle(red); Picker("Apariencia", selection: $appearance) { Text("Oscuro").tag("dark"); Text("Claro").tag("light") }.pickerStyle(.segmented).labelsHidden() }
            Button { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!) } label: { Label("Ítems de inicio de macOS", systemImage: "arrow.up.forward.app").font(.system(size: 12)) }.buttonStyle(.plain)
        }.padding(18).frame(width: 245).background(isLight ? Color(red: 0.91, green: 0.91, blue: 0.93) : Color(red: 0.09, green: 0.09, blue: 0.09))
    }
    private func metric(_ title: String, value: Int, tint: Color) -> some View { HStack { Circle().fill(tint).frame(width: 6, height: 6); Text(title).font(.system(size: 13)).foregroundStyle(.secondary); Spacer(); Text("\(value)").font(.system(size: 14, weight: .semibold)).monospacedDigit() } }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { Text("Elementos de inicio").font(.system(size: 23, weight: .bold)); Text("Servicios y procesos configurados para arrancar con macOS").font(.system(size: 13)).foregroundStyle(.secondary) }
            Spacer()
            HStack(spacing: 7) { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Buscar elementos", text: $model.search).textFieldStyle(.plain).font(.system(size: 14)).frame(width: 165) }
                .padding(9).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
            Button { model.refresh() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).padding(9).background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7)) }.buttonStyle(.plain).help("Volver a analizar")
        }.padding(.horizontal, 24).padding(.vertical, 19).background(isLight ? Color(red: 0.96, green: 0.96, blue: 0.97) : Color(red: 0.085, green: 0.085, blue: 0.095))
    }
    private var list: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ELEMENTO")
                Spacer()
                Picker("Gestión", selection: $model.filter) { Text("Todos").tag("Todo"); Text("Modificables").tag("Modificables"); Text("Protegidos").tag("Protegidos") }.pickerStyle(.segmented).frame(width: 285)
                Text("TIPO").frame(width: 155, alignment: .leading)
                Text("ESTADO").frame(width: 145, alignment: .leading)
            }
                .font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 12)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            if model.isLoading { Spacer(); ProgressView("Analizando el sistema…"); Spacer() }
            else if model.visibleItems.isEmpty { Spacer(); VStack(spacing: 8) { Image(systemName: "checkmark.shield").font(.system(size: 30)).foregroundStyle(red); Text("No se encontraron elementos").font(.system(size: 14, weight: .semibold)); Text("Prueba otra categoría o vuelve a analizar.").font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer() }
            else { ScrollView { LazyVStack(spacing: 0) { ForEach(model.visibleItems) { item in ItemRow(item: item, onToggle: { model.toggle(item, enable: $0) }) } } } }
        }
    }
    private var footer: some View {
        HStack(spacing: 8) { Image(systemName: "lock.shield").foregroundStyle(red); Text("Los cambios en ubicaciones protegidas requieren permisos de administrador.").foregroundStyle(.secondary); Spacer(); Text("macOS").foregroundStyle(.secondary) }.font(.system(size: 12)).padding(.horizontal, 22).padding(.vertical, 13).background(isLight ? Color(red: 0.96, green: 0.96, blue: 0.97) : Color(red: 0.085, green: 0.085, blue: 0.095))
    }
}

struct ItemRow: View {
    let item: StartupItem
    let onToggle: (Bool) -> Void
    private let red = Color(red: 0.95, green: 0.19, blue: 0.22)
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(red.opacity(0.13)).frame(width: 34, height: 34).overlay(Image(systemName: item.kind == "Daemon del sistema" ? "gearshape.2.fill" : "bolt.fill").font(.system(size: 13)).foregroundStyle(red))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.application).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(item.description).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                Text("Desarrollador: \(item.developer)").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Text(item.executablePath).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).help(item.executablePath)
                Text(item.label).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 10)
            Text(item.kind).font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 155, alignment: .leading)
            HStack(spacing: 9) {
                Button { onToggle(item.isDisabled) } label: {
                    ZStack(alignment: item.isDisabled ? .leading : .trailing) {
                        Capsule().fill(item.isDisabled ? Color.secondary.opacity(0.34) : red).frame(width: 52, height: 29)
                        Circle().fill(.white).frame(width: 23, height: 23).padding(3)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!item.manageable)
                .help(item.effect)
                Text(item.isDisabled ? "Apagado" : "Encendido")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(item.isDisabled ? Color.secondary : Color.primary)
                    .fixedSize()
            }.frame(width: 145, alignment: .leading)
            Button { NSWorkspace.shared.selectFile(item.executablePath, inFileViewerRootedAtPath: URL(fileURLWithPath: item.executablePath).deletingLastPathComponent().path) } label: { Image(systemName: "folder").font(.system(size: 14)) }
                .buttonStyle(.plain).help("Mostrar en Finder")
        }.padding(.horizontal, 24).padding(.vertical, 12).overlay(alignment: .bottom) { Rectangle().fill(.primary.opacity(0.06)).frame(height: 1).padding(.leading, 70) }
    }
}

struct SettingsView: View { var body: some View { UpdateView().frame(width: 480, height: 360).preferredColorScheme(.dark) } }

struct UpdateView: View {
    @AppStorage("githubRepo") private var githubRepo = "hernycai/menuinicio"
    @AppStorage("autoUpdate") private var autoUpdate = false
    @State private var status = "Configura el repositorio para buscar versiones publicadas."
    @State private var releaseURL: URL?
    @State private var checking = false
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Image(systemName: "arrow.down.app.fill").foregroundStyle(Color(red: 0.95, green: 0.19, blue: 0.22)).font(.system(size: 25)); VStack(alignment: .leading) { Text("Actualizaciones").font(.system(size: 19, weight: .bold)); Text("Versión instalada: \(version)").font(.system(size: 11)).foregroundStyle(.secondary) }; Spacer() }
            Toggle("Buscar actualizaciones automáticamente", isOn: $autoUpdate).font(.system(size: 14))
            Text(status).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack { Button("Buscar actualizaciones") { check() }.buttonStyle(.borderedProminent).tint(Color(red: 0.78, green: 0.12, blue: 0.16)).disabled(checking || githubRepo.split(separator: "/").count != 2); if let releaseURL { Button("Abrir descarga") { NSWorkspace.shared.open(releaseURL) }.buttonStyle(.bordered) }; Spacer() }
            Spacer(minLength: 0)
            Text("Las versiones directas y automáticas requieren firma Developer ID y notarización. La búsqueda abre las versiones publicadas en GitHub.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.46)).fixedSize(horizontal: false, vertical: true)
        }.padding(24)
    }
    private func check() {
        checking = true; status = "Buscando la versión más reciente…"
        let parts = githubRepo.split(separator: "/").map(String.init)
        guard parts.count == 2, let url = URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/releases/latest") else { checking = false; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                checking = false
                guard error == nil, let data, let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String, let html = json["html_url"] as? String, let page = URL(string: html) else {
                    status = "No se pudo consultar GitHub. Verifica el repositorio y que tenga una versión publicada."; return
                }
                releaseURL = page
                let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                status = latest.compare(version, options: .numeric) == .orderedDescending ? "Hay una versión nueva (\(tag)). Abre la página para descargarla." : "Tienes la última versión publicada (\(tag))."
            }
        }.resume()
    }
}
