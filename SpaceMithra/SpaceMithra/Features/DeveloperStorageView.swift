import SwiftUI

struct DeveloperStorageView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing:20) {
                Text(model.text("dev.intro")).font(.title3)
                Text(model.text("dev.sources")).foregroundStyle(.secondary)
                HStack {
                    Button(model.text("refresh")) {Task{await model.refreshDeveloperStorage()}}.disabled(model.working || model.scanning)
                    if model.loadingDeveloper {ProgressView().controlSize(.small)}
                }
                if model.developerEntries.isEmpty && !model.loadingDeveloper {
                    Label(model.text("dev.empty"),systemImage:"hammer").padding(20)
                }
                ForEach(model.developerEntries) { entry in
                    GroupBox {
                        VStack(alignment:.leading,spacing:10) {
                            HStack {
                                Image(systemName:entry.icon).font(.title2).foregroundStyle(Color.accentColor)
                                VStack(alignment:.leading) {
                                    Text(entry.tool == "Project" ? model.text("dev.projectTool") : entry.tool).font(.headline)
                                    Text(model.text("dev.kind." + entry.kind.rawValue)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.logicalSize.map(model.byteText) ?? model.text("dev.notMeasured")).font(.headline).monospacedDigit()
                            }
                            Text(model.text(entry.canReviewCache ? "dev.cachePurpose":"dev.statePurpose"))
                            Text(model.text(entry.canReviewCache ? "dev.cacheConsequence" : "dev.keepState")).font(.callout).foregroundStyle(.secondary)
                            HStack {
                                Button(model.text(entry.logicalSize == nil ? "dev.scanLocation" : "dev.explore")) {model.openDeveloperLocation(entry)}
                                    .disabled(model.scanning || model.working || model.duplicateWorking)
                                Spacer()
                                if entry.kind != .cache {Label(model.text("riskLevel.protected"),systemImage:"lock.shield").font(.caption)}
                            }
                            DisclosureGroup(model.text("technicalDetails")) {
                                VStack(alignment:.leading,spacing:8) {
                                    Text(entry.url.path).font(.caption).textSelection(.enabled)
                                    Text(model.text("dev.mechanism"))
                                    if let command=entry.inspectCommand {
                                        Text(command).font(.system(.callout,design:.monospaced)).textSelection(.enabled)
                                        Button(model.text("dev.copyInspect")) {NSPasteboard.general.clearContents();NSPasteboard.general.setString(command,forType:.string)}
                                    }
                                }.frame(maxWidth:.infinity,alignment:.leading).padding(.top,8)
                            }
                        }.padding(14)
                    }
                }
                if model.developerEntries.count >= 1000 {Text(model.text("dev.limit")).font(.caption)}
            }.padding(24)
        }.task {await model.refreshDeveloperStorage()}
    }
}
