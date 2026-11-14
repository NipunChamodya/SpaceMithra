import SwiftUI

struct ScanningView:View {
    @ObservedObject var model:AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating=false
    private var active:Bool {model.progress.state == .scanning && !reduceMotion}
    var body: some View {
        VStack(spacing:24) {
            ZStack {
                Circle().stroke(Color.accentColor.opacity(0.12),lineWidth:10)
                Circle().trim(from:0.1,to:0.8).stroke(Color.accentColor,style:StrokeStyle(lineWidth:10,lineCap:.round))
                    .rotationEffect(.degrees(rotating ? 360:0))
                    .animation(active ? .linear(duration:4).repeatForever(autoreverses:false):nil,value:rotating)
                Image(systemName:"internaldrive").font(.system(size:60)).foregroundStyle(Color.accentColor)
            }.frame(width:170,height:170).accessibilityHidden(true)
            Text(model.text("scan.title")).font(.largeTitle.bold())
            Text(model.text(model.progress.state == .paused ? "state.paused":"scan.finding")).font(.title3).foregroundStyle(.secondary)
            Text("\(model.progress.count) " + model.text("items") + " · " + model.byteText(model.progress.bytes)).font(.title3).monospacedDigit()
                .accessibilityLabel(model.text("scan.progressAccessibility"))
                .accessibilityValue("\(model.progress.count) " + model.text("items") + " · " + model.byteText(model.progress.bytes))
            if !model.progress.current.isEmpty {
                Label(URL(fileURLWithPath:model.progress.current).deletingLastPathComponent().lastPathComponent,systemImage:"folder")
                    .lineLimit(1).frame(maxWidth:400).foregroundStyle(.secondary)
            }
            Text(model.text("scan.indeterminate")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:500)
            HStack(spacing:16) {
                Button(model.text(model.progress.state == .paused ? "resume":"pause")){model.pause()}
                    .disabled(model.progress.state == .preparing)
                Button(model.text("cancel")){model.cancel()}.keyboardShortcut(.cancelAction)
            }
            Label(model.text("welcome.readOnly"),systemImage:"checkmark.shield").font(.caption)
            if model.progress.errors>0 {Text("\(model.progress.errors) " + model.text("scan.permissionSummary")).font(.caption).frame(maxWidth:500)}
        }.padding(32).frame(maxWidth:.infinity,maxHeight:.infinity)
            .onAppear{rotating=active}
            .onChange(of:model.progress.state){_ in rotating=active}
            .onChange(of:reduceMotion){_ in rotating=active}
    }
}
