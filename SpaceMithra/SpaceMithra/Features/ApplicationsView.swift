import SwiftUI

struct ApplicationsView: View {
    @ObservedObject var model:AppModel
    @State private var selected:ApplicationStorage?
    @State private var search=""
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text(model.text("apps.intro")).foregroundStyle(.secondary)
                Spacer()
                if model.loadingApplications {ProgressView().controlSize(.small)}
                Button(model.text("refresh")){Task{await model.refreshApplications()}}.disabled(model.loadingApplications || model.working || model.scanning)
            }.padding(.horizontal,24).padding(.top,20)
            TextField(model.text("search"),text:$search).textFieldStyle(.roundedBorder).padding(.horizontal,24)
            ScrollView {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:260),spacing:16)],spacing:16) {
                    ForEach(model.applications.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)}) { app in
                        Button {selected=app} label:{
                            VStack(alignment:.leading,spacing:14) {
                                HStack {ApplicationIcon(url:app.url);Text(app.name).font(.headline).lineLimit(2);Spacer()}
                                metric("apps.bundle",app.bundleSize)
                                metric("apps.cache",app.cacheSize)
                                metric("apps.related",app.relatedDataSize)
                                Text(model.text("apps.bundleDescription")).font(.caption).foregroundStyle(.secondary)
                            }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
                                .background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:16))
                                .overlay(RoundedRectangle(cornerRadius:16).stroke(Color.primary.opacity(0.12)))
                        }.buttonStyle(.plain).accessibilityLabel(app.name + ", " + model.text("apps.overview")).accessibilityIdentifier("application."+(app.bundleIdentifier ?? app.url.path))
                    }
                }.padding(24)
                if model.applications.isEmpty && !model.loadingApplications {Label(model.text("apps.empty"),systemImage:"app.dashed").padding(30)}
            }
        }.task{await model.refreshApplications()}
        .sheet(item:$selected){app in ApplicationDetailView(app:app,model:model){selected=nil}}
    }
    private func metric(_ key:String,_ size:Int64?)->some View {
        HStack{Text(model.text(key)).foregroundStyle(.secondary);Spacer();Text(size.map(model.byteText) ?? model.text(key == "apps.bundle" ? "dev.notMeasured" : "unavailable")).monospacedDigit()}.font(.callout)
    }
}
struct ApplicationIcon: View {
    let url:URL
    @State private var icon:NSImage?
    var body: some View {
        Group {
            if let icon {Image(nsImage:icon).resizable().scaledToFit()}
            else {Image(systemName:"app.fill").resizable().scaledToFit().foregroundStyle(Color.accentColor)}
        }.frame(width:48,height:48).accessibilityHidden(true)
            .onAppear{if icon == nil {icon=NSWorkspace.shared.icon(forFile:url.path)}}
    }
}
private struct ApplicationDetailView:View {
    let app:ApplicationStorage
    @ObservedObject var model:AppModel
    let close:()->Void
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack{ApplicationIcon(url:app.url);Text(app.name).font(.largeTitle.bold());Spacer();Button(model.text("ok"),action:close).keyboardShortcut(.cancelAction)}
                Text(model.text("apps.bundleDescription"))
                value("apps.bundle",app.bundleSize);value("apps.cache",app.cacheSize);value("apps.related",app.relatedDataSize)
                Text(model.text("apps.lastUsed") + ": " + (app.lastUsed.map(model.dateText) ?? model.text("unavailable")))
                Text(model.text("apps.attribution")).font(.callout).foregroundStyle(.secondary)
                ForEach(app.cacheURLs,id:\.path){url in
                    Button(model.text("apps.reviewCache")){close();model.openStorageLocation(url,destination:"caches")}.disabled(model.working || model.scanning || model.duplicateWorking)
                }
                ForEach(app.relatedDataURLs,id:\.path){url in
                    HStack{Text(model.text("apps.related"));Spacer();Button(model.text("reveal")){NSWorkspace.shared.activateFileViewerSelecting([url])}}.help(url.path)
                }
                Text(model.text("apps.leftovers") + ": " + model.text("unavailable")).foregroundStyle(.secondary)
                DisclosureGroup(model.text("technicalDetails")) {
                    VStack(alignment:.leading,spacing:12) {
                        Text(app.url.path).textSelection(.enabled)
                        Text(app.bundleIdentifier ?? model.text("unavailable")).textSelection(.enabled)
                        Button(model.text("apps.technicalFiles")){close();model.openStorageLocation(app.url,destination:"explorer")}.disabled(model.working || model.scanning || model.duplicateWorking)
                        Text(model.text("apps.noUninstall")).font(.caption)
                    }.padding(.top,10)
                }
            }.padding(28)
        }.frame(width:640,height:620)
    }
    private func value(_ key:String,_ size:Int64?)->some View {
        HStack{Text(model.text(key));Spacer();Text(size.map(model.byteText) ?? model.text(key == "apps.bundle" ? "dev.notMeasured" : "unavailable")).font(.headline).monospacedDigit()}
    }
}
