import SwiftUI

struct WelcomeView:View {
    @ObservedObject var model:AppModel
    var body: some View {
        ScrollView {
            VStack(spacing:26) {
                StorageIllustration().padding(.top,28)
                Text(model.text("welcome.title")).font(.system(.largeTitle,design:.rounded).bold()).multilineTextAlignment(.center)
                Text(model.text("welcome.description")).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:550)
                Button(action:model.scanMyMac){Label(model.text("scanMyMac"),systemImage:"sparkle.magnifyingglass").font(.headline).padding(.horizontal,26).padding(.vertical,10)}
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.catalog == nil || model.working)
                    .accessibilityIdentifier("scanMyMac")
                Label(model.text("welcome.readOnly"),systemImage:"checkmark.shield").font(.callout)
                LanguageChoice(model:model).frame(maxWidth:300)
                StorageSurface {
                    VStack(alignment:.leading,spacing:12) {
                        Label(model.text("privacy"),systemImage:"lock.shield")
                        Text(model.text("welcome.permissions")).foregroundStyle(.secondary)
                    }.font(.callout)
                }.frame(maxWidth:620)
                Button(model.text("advancedExplore")){model.showAdvanced=true;model.chooseFolder()}.buttonStyle(.link).disabled(model.catalog == nil)
                if let disk=model.startupDisk {Text(disk.name + " · " + model.capacityText(disk.total)).font(.caption).foregroundStyle(.secondary)}
            }.padding(32).frame(maxWidth:.infinity)
        }
    }
}
struct LanguageChoice:View {
    @ObservedObject var model:AppModel
    var body: some View {
        Picker(model.text("language"),selection:$model.language) {
            ForEach([("si","සිංහල"),("ta","தமிழ்"),("en","English"),("hi","हिन्दी"),("ar","العربية"),("fr","Français"),("zh-Hans","简体中文")],id:\.0){Text($0.1).tag($0.0)}
        }.accessibilityIdentifier("languagePicker")
    }
}
