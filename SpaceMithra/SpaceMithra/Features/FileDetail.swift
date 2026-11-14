import SwiftUI
import QuickLookUI
import UniformTypeIdentifiers

struct FileDetail: View {
    let file: FileRecord
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                Text(file.name).font(.title3.bold()).textSelection(.enabled)
                Divider()
                field("size", model.byteText(file.logical))
                DisclosureGroup(model.text("technicalDetails")) {
                field("path", file.path)
                field("type", file.typeIdentifier.flatMap { UTType($0)?.localizedDescription } ?? model.text("unavailable"))
                field("category", model.text("category." + file.category.rawValue))
                field("extension", URL(fileURLWithPath: file.path).pathExtension)
                field("allocated", file.allocated.map(model.byteText) ?? model.text("unavailable"))
                field("created", file.created.map(model.dateText) ?? model.text("unavailable"))
                field("modified", file.modified.map(model.dateText) ?? model.text("unavailable"))
                field("opened", file.opened.map(model.dateText) ?? model.text("unavailable"))
                field("associatedApplication", associatedApplication)
                field("owner", Classifier.recognizedCache(file.path) ?? model.text("unavailable"))
                if let rule = StorageRule.all.first(where: { $0.matches(file.path) }) { field("regeneration", model.text(rule.mayRegenerate ? "mayRegenerate" : "notRegenerable")) }
                field("activeUse", model.text("unavailable"))
                }
                Divider()
                Label(model.text("riskLevel." + model.assessment(file).risk.rawValue), systemImage: model.assessment(file).eligible ? "exclamationmark.triangle" : "lock.shield")
                Text(model.text(model.assessment(file).explanation))
                Text(model.text(model.assessment(file).consequence)).foregroundStyle(.secondary)
                Text(model.text("recoveryNotice")).font(.caption)
                Button(model.text("reveal")) { model.reveal(file) }
                if !file.isDirectory && !file.isSymlink { Button(model.text("preview")) { PreviewController.shared.show(URL(fileURLWithPath: file.path)) } }
                HStack {
                    Button(model.text("keep")) { model.keep(file) }
                    Button(model.text("clean")) { model.enqueue(file) }.disabled(!model.assessment(file).eligible || model.scanning || model.working || model.duplicateWorking)
                }
                Menu(model.text("protect")) {
                    Button(model.text("permanent")) { model.protect(file) }
                    Button(model.text("oneDay")) { model.protect(file, temporary: true) }
                }
            }.font(.callout).padding(18)
        }
    }
    private var associatedApplication: String {
        guard let app = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: file.path)) else { return model.text("unavailable") }
        return FileManager.default.displayName(atPath: app.path)
    }
    private func field(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(model.text(key)).font(.caption).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }
}
@MainActor final class PreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = PreviewController()
    private var url: URL?
    func show(_ url: URL) { self.url = url; guard let panel = QLPreviewPanel.shared() else { return }; panel.dataSource = self; panel.reloadData(); panel.makeKeyAndOrderFront(nil) }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! { url as NSURL? }
}
