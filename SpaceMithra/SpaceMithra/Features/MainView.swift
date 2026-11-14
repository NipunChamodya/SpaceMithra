import SwiftUI
import Charts
import QuickLookUI

struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var confirming = false
    @State private var recovery: HistoryEntry?
    @AppStorage("onboarded") private var onboarded = false
    private let destinations: [(String, String)] = [("dashboard", "chart.pie"), ("explorer", "internaldrive"), ("caches", "square.stack.3d.up"), ("biggest", "chart.bar"), ("duplicates", "doc.on.doc"), ("developer", "hammer"), ("queue", "tray.full"), ("protected", "lock.shield"), ("recovery", "clock.arrow.circlepath"), ("settings", "gearshape")]
    var body: some View {
        NavigationSplitView {
            List {
                Section("SpaceMithra") {
                    ForEach(destinations.filter { $0.0 != "developer" || model.developerMode }, id: \.0) { key, icon in
                        Button { model.switchSection(key) } label: { Label(model.text(key), systemImage: icon).foregroundStyle(model.section == key ? Color.accentColor : .primary) }
                            .buttonStyle(.plain).padding(.vertical, 4).accessibilityIdentifier("nav.\(key)")
                    }
                }
                Section(model.text("locations")) {
                    Button { model.chooseFolder() } label: { Label(model.text("allAccessible"), systemImage: "folder.badge.plus") }
                    ForEach(model.locations, id: \.0) { key, icon, url in
                        Button { model.scan(url) } label: { Label(model.text(key), systemImage: icon) }.disabled(model.scanning || model.working)
                    }
                }
                Section(model.text("volumes")) {
                    ForEach(model.volumes, id: \.path) { url in
                        Button { model.scan(url) } label: { Label(url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent, systemImage: "externaldrive") }.disabled(model.scanning || model.working)
                    }
                }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.text(model.section)).font(.largeTitle.bold())
                        Text(model.root?.path ?? model.text("welcomeSubtitle")).font(.caption).foregroundStyle(.secondary).lineLimit(1).textSelection(.enabled)
                    }
                    Spacer()
                    Button { model.chooseFolder() } label: { Label(model.text("chooseFolder"), systemImage: "folder.badge.plus") }
                        .disabled(model.scanning || model.working || model.duplicateWorking).accessibilityIdentifier("chooseFolder")
                }.padding(20)
                Divider()
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                statusBar
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .alert(model.text("error"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.text("ok")) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .sheet(isPresented: $confirming) { confirmation }
        .alert(model.text("restore"), isPresented: Binding(get: { recovery != nil }, set: { if !$0 { recovery = nil } })) {
            Button(model.text("cancel"), role: .cancel) { recovery = nil }
            Button(model.text("restore")) { if let recovery { model.restore(recovery) }; recovery = nil }
        } message: { Text(model.text("restoreWarning") + "\n" + (recovery?.record.path ?? "")) }
        .sheet(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) { onboarding }
    }
    @ViewBuilder private var content: some View {
        switch model.section {
        case "dashboard": dashboard
        case "queue": queue
        case "protected": protectionList
        case "recovery": historyList
        case "settings": settings
        case "duplicates": duplicateList
        default: explorer
        }
    }
    private var statusBar: some View {
        HStack {
            if model.scanning { ProgressView().controlSize(.small) }
            Text(model.text("state." + model.progress.state.rawValue))
            Text("\(model.progress.count) " + model.text("items") + " · " + byteString(model.progress.bytes))
            Text("\(model.progress.reused) " + model.text("reused")).foregroundStyle(.secondary)
            Text("\(model.progress.errors) " + model.text("scanErrors")).foregroundStyle(.secondary)
            if model.progress.state != .idle { Text(Date().timeIntervalSince(model.progress.started), format: .number.precision(.fractionLength(0))).monospacedDigit(); Text(model.text("seconds")) }
            Spacer()
            if model.scanning {
                Button(model.text(model.progress.state == .paused ? "resume" : "pause")) { model.pause() }
                Button(model.text("cancel")) { model.cancel() }
            }
            Button(model.text("queue") + " (\(model.queue.count))") { model.switchSection("queue") }
        }.font(.caption).padding(12)
    }
    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label(model.text("privacy"), systemImage: "lock.shield").font(.headline)
                Text(model.text("scanGuidance")).foregroundStyle(.secondary)
                if let root = model.root,
                   let values = try? root.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                   let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                    GroupBox(model.text("diskUsage")) {
                        VStack(alignment: .leading) {
                            ProgressView(value: Double(total - available), total: Double(total)).accessibilityLabel(model.text("diskUsage"))
                            Text(byteString(Int64(total - available)) + " / " + byteString(Int64(total)))
                        }.padding()
                    }
                }
                GroupBox(model.text("distribution")) {
                    Text(model.text("partialNotice")).font(.caption).foregroundStyle(.secondary)
                    StorageMap(records: model.rows.filter { $0.logical > 0 }, model: model)
                }
                if !model.scanIssues.isEmpty {
                    GroupBox(model.text("scanIssues")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(model.scanIssues) { issue in
                                VStack(alignment: .leading) {
                                    Text(issue.path).font(.caption.bold()).textSelection(.enabled)
                                    Text(model.text(issue.message)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }
                }
                if model.trends.count > 1 {
                    GroupBox(model.text("trends")) {
                        Text(model.text("trendNotice")).font(.caption)
                        Chart(Array(model.trends.enumerated()), id: \.offset) { _, point in
                            LineMark(x: .value(model.text("date"), point.0), y: .value(model.text("size"), point.1))
                        }.frame(height: 150).accessibilityLabel(model.text("trends"))
                    }
                }
            }.padding(24)
        }
    }
    private var explorer: some View {
        VStack(spacing: 0) {
            if ["caches", "developer"].contains(model.section) {
                HStack {
                    Picker(model.text("owner"), selection: $model.storageGroup) {
                        Text(model.text("all")).tag(nil as String?)
                        ForEach(model.discoveredStorage.filter { model.section == "caches" ? $0.rule.isCache : $0.rule.group == "development" }) { group in
                            Text(model.text("group." + group.rule.group) + " / " + group.rule.owner + " · " + byteString(group.bytes)).tag(Optional(group.id))
                        }
                    }.onChange(of: model.storageGroup) { _ in reload() }
                    Text(model.text("activeUse") + ": " + model.text("unavailable")).font(.caption).foregroundStyle(.secondary)
                }.padding(12)
            }
            HStack {
                if let folder = model.folder, model.section == "explorer" {
                    Button { model.navigate(URL(fileURLWithPath: folder).deletingLastPathComponent().path) } label: { Image(systemName: "chevron.up") }
                        .disabled(folder == model.root?.path).accessibilityLabel(model.text("parentFolder"))
                    ScrollView(.horizontal) {
                        HStack(spacing: 4) {
                            ForEach(breadcrumbs(folder), id: \.self) { path in
                                Button(URL(fileURLWithPath: path).lastPathComponent) { model.navigate(path) }.buttonStyle(.link)
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                        }
                    }
                }
                TextField(model.text("search"), text: $model.search).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    .onChange(of: model.search) { _ in reload() }
                Picker(model.text("sort"), selection: $model.sort) {
                    Text(model.text("size")).tag("size"); Text(model.text("name")).tag("name"); Text(model.text("type")).tag("type"); Text(model.text("modified")).tag("date")
                }.frame(width: 150).onChange(of: model.sort) { _ in reload() }
                Picker(model.text("category"), selection: $model.category) {
                    Text(model.text("all")).tag(nil as FileCategory?)
                    ForEach(FileCategory.allCases, id: \.self) { Text(model.text("category." + $0.rawValue)).tag(Optional($0)) }
                }.frame(width: 180).onChange(of: model.category) { _ in reload() }
            }.padding(12)
            if model.section == "explorer" && !model.columns.isEmpty {
                FolderColumns(model: model).frame(height: 155)
                Divider()
            }
            if model.section == "biggest" {
                HStack {
                    Text(model.text("minimumMB")); TextField("MB", text: $model.minimumMB).frame(width: 70)
                    TextField(model.text("extension"), text: $model.extensionFilter).frame(width: 130)
                    DatePicker(model.text("modifiedAfter"), selection: $model.modifiedSince, displayedComponents: .date)
                    Button(model.text("apply")) { reload() }
                }.padding(.horizontal).padding(.bottom, 8)
            }
            if model.scanning { Text(model.text("scanInProgress")).font(.caption).padding(8) }
            HSplitView {
                VStack(spacing: 0) {
                    Table(model.rows, selection: $model.selection) {
                        TableColumn(model.text("name")) { file in
                            HStack {
                                Image(systemName: file.isDirectory ? "folder.fill" : "doc").foregroundStyle(file.isDirectory ? .blue : .secondary)
                                Button(file.name) { if file.isDirectory { model.navigate(file.path) } else { model.selection = file.path } }.buttonStyle(.plain)
                            }.help(file.path)
                        }.width(min: 160, ideal: 260)
                        TableColumn(model.text("size")) { Text(byteString($0.logical)).monospacedDigit() }.width(90)
                        TableColumn(model.text("risk")) { Text(model.text("riskLevel." + model.assessment($0).risk.rawValue)).font(.caption) }.width(110)
                        TableColumn(model.text("clean")) { file in
                            Toggle(model.text("clean"), isOn: Binding(get: { model.queue.contains { $0.path == file.path } }, set: { if $0 { model.enqueue(file) } else { model.keep(file) } }))
                                .labelsHidden().disabled(!model.assessment(file).eligible || model.progress.state != .completed || model.working)
                                .accessibilityLabel(model.text("clean") + " " + file.name)
                        }.width(50)
                    }.contextMenu {
                        if let file = model.selected { fileActions(file) }
                    }
                    HStack {
                        Button(model.text("previous")) { model.page -= 1; Task { await model.refresh() } }.disabled(model.page == 0)
                        Text("\(model.page + 1)").monospacedDigit()
                        Button(model.text("next")) { model.page += 1; Task { await model.refresh() } }.disabled(!model.hasMore)
                        Spacer()
                        Image(systemName: pageSelectionSymbol).accessibilityLabel(model.text("queue"))
                        Text("\(model.rows.filter { file in model.queue.contains { $0.path == file.path } }.count) / \(model.rows.filter { model.assessment($0).eligible }.count)")
                        Button(model.text("selectEligible")) { model.rows.forEach { model.enqueue($0) } }.disabled(model.scanning)
                        Button(model.text("deselectPage")) { model.rows.forEach { model.keep($0) } }
                    }.font(.caption).padding(10)
                }.frame(minWidth: 430)
                if let selected = model.selected { FileDetail(file: selected, model: model).frame(minWidth: 260, idealWidth: 300, maxWidth: 380) }
            }
        }
    }
    @ViewBuilder private func fileActions(_ file: FileRecord) -> some View {
        Button(model.text("reveal")) { model.reveal(file) }
        Button(model.text("clean")) { model.enqueue(file) }.disabled(!model.assessment(file).eligible || model.scanning)
        Button(model.text("keep")) { model.keep(file) }
        Button(model.text("protect")) { model.protect(file) }
    }
    private var queue: some View {
        VStack(alignment: .leading) {
            Text(model.text("trashWarning")).padding()
            List(model.queue) { file in
                HStack {
                    VStack(alignment: .leading) {
                        Text(file.name).font(.headline); Text(file.path).font(.caption).textSelection(.enabled)
                        Text(model.text(model.assessment(file).explanation)).font(.caption)
                        Text(model.text(model.assessment(file).consequence)).font(.caption).foregroundStyle(.secondary)
                        Text(model.text("riskLevel." + model.assessment(file).risk.rawValue))
                    }
                    Spacer(); Text(byteString(file.logical))
                    Button(model.text("keep")) { model.keep(file) }.disabled(model.working)
                }
            }
            HStack {
                Text(byteString(model.queuedBytes) + " · \(model.queue.count) " + model.text("items"))
                Spacer()
                Button(model.text("deselectAll")) { model.queue.removeAll() }.disabled(model.working)
                Button(model.text("reviewTrash")) {
                    Task { await model.prepareCleanupReview(); confirming = model.cleanupReview != nil }
                }.disabled(model.queue.isEmpty || model.scanning || model.working)
            }.padding()
        }
    }
    private var confirmation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.text("confirmTitle")).font(.title2.bold())
            Text(model.text("trashWarning"))
            Text(model.text("review.guidance"))
            if let review = model.cleanupReview {
                HStack {
                    Label("\(review.readyCount) " + model.text("review.ready"), systemImage: "checkmark.circle")
                    Label("\(review.blockedCount) " + model.text("review.blocked"), systemImage: "exclamationmark.triangle")
                }.font(.callout)
                List(review.items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.record.path).textSelection(.enabled)
                        Text(byteString(item.record.logical) + " · " + model.text("riskLevel." + item.assessment.risk.rawValue))
                        Text(model.text(item.assessment.consequence)).foregroundStyle(.secondary)
                        if let blocker = item.blocker {
                            Label(model.text(blocker), systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                        }
                    }.padding(.vertical, 4)
                }.frame(height: 280)
                HStack {
                    Text(byteString(review.estimatedSelectedBytes)); Spacer()
                    Button(model.text("cancel"), role: .cancel) { model.cancelCleanupReview(); confirming = false }.keyboardShortcut(.cancelAction)
                    Button(model.text("moveToTrash"), role: .destructive) { confirming = false; model.performCleanup(confirmed: review) }
                        .disabled(!model.isCurrentReview(review))
                        .accessibilityIdentifier("confirmCleanup")
                }
            }
        }.padding(24).frame(width: 680)
        .onDisappear { model.cancelCleanupReview() }
    }
    private var protectionList: some View {
        List(model.protections) { rule in
            HStack {
                VStack(alignment: .leading) { Text(rule.path).textSelection(.enabled); Text(rule.expires.map { $0.formatted() } ?? model.text("permanent")).font(.caption) }
                Spacer(); Button(model.text("removeProtection")) { model.unprotect(rule) }
            }
        }
    }
    private var historyList: some View {
        List {
            ForEach(model.historySessions) { session in
                Section {
                    ForEach(session.entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.record.name).font(.headline)
                                Text(entry.record.path).font(.caption).textSelection(.enabled)
                                Text(model.text("history." + entry.status))
                                Text(model.text(entry.message)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            if entry.status == "trashed" {
                                Button(model.text("restore")) { recovery = entry }.disabled(model.working || entry.trashIdentity == nil)
                            }
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.date.formatted()).font(.headline)
                        Text(model.text("cleanupSession") + " " + session.id).font(.caption).textSelection(.enabled)
                        Text(model.text("estimatedSelected") + ": " + byteString(session.estimatedSelectedBytes))
                        ForEach(session.counts.keys.sorted(), id: \.self) { status in
                            Text(model.text("history." + status) + ": \(session.counts[status] ?? 0)")
                        }
                    }.textCase(nil).padding(.vertical, 5)
                }
            }
        }
    }
    private var duplicateList: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(model.text("duplicateGuidance")); Spacer()
                if model.duplicateWorking {
                    ProgressView(); Text("\(model.duplicateCount)")
                    Button(model.text("cancel")) { model.cancelDuplicates() }
                } else {
                    Button(model.text("findDuplicates")) { model.findDuplicates() }.disabled(model.root == nil || model.scanning)
                }
            }.padding()
            List {
                ForEach(model.duplicates) { group in
                    Section(byteString(group.files.first?.logical ?? 0)) {
                        ForEach(group.files) { file in
                            HStack {
                                Text(file.path).textSelection(.enabled); Spacer()
                                Button(model.text("reveal")) { model.reveal(file) }
                                Button(model.text("clean")) { model.enqueue(file) }
                                    .disabled(!model.assessment(file).eligible || model.queue.filter { f in group.files.contains { $0.path == f.path } }.count >= group.files.count - 1 || model.queue.contains { $0.path == file.path })
                            }
                        }
                    }
                }
            }
        }
    }
    private var settings: some View {
        Form {
            Picker(model.text("language"), selection: $model.language) {
                ForEach([("si", "සිංහල"), ("ta", "தமிழ்"), ("en", "English"), ("hi", "हिन्दी"), ("ar", "العربية"), ("fr", "Français"), ("zh-Hans", "简体中文")], id: \.0) { Text($0.1).tag($0.0) }
            }
            Toggle(model.text("developerMode"), isOn: $model.developerMode)
            Toggle(model.text("showHidden"), isOn: $model.showHidden).onChange(of: model.showHidden) { _ in reload() }
            Text(model.text("privacy"))
            Text(model.text("translationNotice")).foregroundStyle(.secondary)
            Text(model.text("limitations")).foregroundStyle(.secondary)
        }.formStyle(.grouped).padding()
    }
    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("SpaceMithra", systemImage: "internaldrive").font(.largeTitle.bold())
            Text(model.text("welcomeSubtitle")).font(.title3)
            Text(model.text("scanGuidance"))
            Text(model.text("privacy"))
            Text(model.text("trashWarning"))
            Button(model.text("getStarted")) { onboarded = true }.keyboardShortcut(.defaultAction)
        }.padding(32).frame(width: 520)
    }
    private var pageSelectionSymbol: String {
        let eligible = model.rows.filter { model.assessment($0).eligible }
        let selected = eligible.filter { file in model.queue.contains { $0.path == file.path } }.count
        return selected == 0 ? "square" : selected == eligible.count ? "checkmark.square" : "minus.square"
    }
    private func reload() { model.page = 0; Task { await model.refresh() } }
    private func breadcrumbs(_ path: String) -> [String] {
        guard let root = model.root?.path, path.hasPrefix(root) else { return [path] }
        let suffix = String(path.dropFirst(root.count)).split(separator: "/")
        var result = [root], current = root
        for component in suffix { current = URL(fileURLWithPath: current).appendingPathComponent(String(component)).path; result.append(current) }
        return result
    }
}

