import SwiftUI
import Charts

struct DashboardView:View {
    @ObservedObject var model:AppModel
    private let buckets:[(String,String)]=[("applications","app.fill"),("images","photo.fill"),("videos","video.fill"),("documents","doc.text.fill"),("downloads","arrow.down.circle.fill"),("caches","clock.arrow.circlepath"),("developer","hammer.fill"),("other","square.grid.2x2.fill")]
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:26) {
                HStack {
                    VStack(alignment:.leading,spacing:6){Text(model.text("dashboard.yourStorage")).font(.largeTitle.bold()).accessibilityIdentifier("storageOverview");Text(model.text("welcome.readOnly")).foregroundStyle(.secondary)}
                    Spacer()
                    Button(action:model.scanMyMac){Label(model.text("scanMyMac"),systemImage:"arrow.clockwise")}.buttonStyle(.borderedProminent).disabled(model.working || model.duplicateWorking || model.catalog == nil)
                }
                if let disk=model.startupDisk {capacityCard(disk)}
                if model.scanWasInterrupted || [.cancelled,.failed].contains(model.progress.state) {
                    Label(model.text("scan.interrupted"),systemImage:"exclamationmark.triangle").font(.callout).padding(14)
                        .background(Color.orange.opacity(0.1),in:RoundedRectangle(cornerRadius:12))
                }
                StorageSurface {
                    VStack(alignment:.leading,spacing:10) {
                        HStack{Text(model.text("scan.coverage")).font(.headline);Spacer();if let date=model.lastScanDate {Text(model.dateText(date)).font(.caption).foregroundStyle(.secondary)}}
                        if let root=model.root {Label(root.path == "/" ? (model.scanDisk?.name ?? "/"):root.lastPathComponent,systemImage:"folder").font(.callout).lineLimit(1)}
                        Text(model.text("scan.partial")).foregroundStyle(.secondary)
                        Text(model.text("scan.logical") + ": " + model.byteText(model.storageSummary.logical)).font(.title3.bold())
                        if model.progress.errors>0 {Label("\(model.progress.errors) " + model.text("scan.permissionSummary"),systemImage:"lock.shield")}
                        DisclosureGroup(model.text("technicalDetails")) {
                            VStack(alignment:.leading,spacing:8) {
                                Text(model.root?.path ?? model.text("scan.notStarted")).textSelection(.enabled)
                                Text(model.text("allocated") + ": " + model.byteText(model.storageSummary.allocatedKnown))
                                Text(model.text("disk.systemLogical") + ": " + model.byteText(model.storageSummary.systemLogical))
                                Text(model.text("disk.protected") + ": " + model.text("unavailable"))
                            }.font(.caption).padding(.top,8)
                        }
                        Button(model.text("scan.allowFolder")){model.chooseFolder()}.disabled(model.working || model.duplicateWorking)
                    }
                }
                Text(model.text("dashboard.takingSpace")).font(.title2.bold())
                LazyVGrid(columns:[GridItem(.adaptive(minimum:225),spacing:16)],spacing:16) {
                    ForEach(buckets,id:\.0){key,icon in
                        Button{model.openCategory(key)}label:{
                            StorageSurface {
                                VStack(alignment:.leading,spacing:12) {
                                    Image(systemName:icon).font(.title2).foregroundStyle(Color.accentColor).accessibilityHidden(true)
                                    Text(model.text("bucket."+key)).font(.headline)
                                    Text(model.byteText(model.categoryBuckets[key] ?? 0)).font(.title2.bold()).monospacedDigit()
                                    Text(model.text("bucket.explain."+key)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                                    Label(model.text("explore"),systemImage:"arrow.right").font(.callout).foregroundStyle(Color.accentColor)
                                }.frame(maxWidth:.infinity,alignment:.leading)
                            }
                        }.buttonStyle(.plain).disabled(model.working || model.duplicateWorking)
                    }
                }
                Text(model.text("dashboard.logicalNotice")).font(.caption).foregroundStyle(.secondary)
                Text(model.text("dashboard.review")).font(.title2.bold())
                ForEach(model.reviewSuggestions){suggestion in
                    StorageSurface {
                        HStack {
                            VStack(alignment:.leading,spacing:6) {
                                Text(model.text("suggestion."+suggestion.id)).font(.headline)
                                Text("\(suggestion.count) " + model.text("items") + " · " + model.byteText(suggestion.bytes)).font(.callout)
                                Text(model.text("suggestion.explain."+suggestion.id)).font(.callout).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.text("explore")){model.openSuggestion(suggestion.id)}.disabled(model.working || model.duplicateWorking)
                        }
                    }
                }
                StorageSurface {
                    HStack {
                        VStack(alignment:.leading,spacing:6){Text(model.text("duplicates")).font(.headline);Text(model.text("dashboard.duplicates")).foregroundStyle(.secondary)}
                        Spacer();Button(model.text("explore")){model.switchSection("duplicates")}
                    }
                }
                DisclosureGroup(model.text("advancedExplore")) {
                    VStack(alignment:.leading,spacing:16) {
                        Text(model.text("partialNotice")).font(.caption).foregroundStyle(.secondary)
                        StorageMap(records:model.rows.filter{$0.logical>0},model:model)
                        Button(model.text("explorer")){model.showAdvanced=true;model.switchSection("explorer")}
                        if model.trends.count>1 {
                            Text(model.text("trendNotice")).font(.caption)
                            Chart(Array(model.trends.enumerated()),id:\.offset){_,point in
                                LineMark(x:.value(model.text("date"),point.0),y:.value(model.text("size"),point.1))
                            }.frame(height:140).accessibilityLabel(model.text("trends"))
                        }
                    }.padding(.top,12)
                }
                if !model.scanIssues.isEmpty {
                    DisclosureGroup(model.text("scanIssues")) {
                        LazyVStack(alignment:.leading,spacing:12){ForEach(model.scanIssues){issue in VStack(alignment:.leading){Text(issue.path).font(.caption).textSelection(.enabled);Text(model.text(issue.message)).font(.caption).foregroundStyle(.secondary)}}}
                    }
                }
            }.padding(24)
        }
    }
    private func capacityCard(_ disk:DiskCapacitySnapshot)->some View {
        StorageSurface {
            VStack(alignment:.leading,spacing:18) {
                Label(disk.name,systemImage:"internaldrive.fill").font(.title2.bold())
                HStack {
                    capacity("disk.total",disk.total);Spacer();capacity("disk.used",disk.used);Spacer();capacity("disk.available",disk.available)
                }
                ProgressView(value:Double(disk.used),total:Double(disk.total))
                    .accessibilityLabel(model.text("disk.used")).accessibilityValue(model.capacityText(disk.used) + " / " + model.capacityText(disk.total))
                Text(model.text("disk.shared")).foregroundStyle(.secondary)
                if let accounting=model.diskAccounting {
                    Text(model.text("disk.otherEstimate") + ": " + (accounting.unattributedUsedEstimate.map(model.capacityText) ?? model.text("unavailable"))).font(.callout)
                }
                DisclosureGroup(model.text("technicalDetails")) {
                    VStack(alignment:.leading,spacing:8) {
                        Text(model.text("disk.capacitySource"));Text(model.text("disk.attribution"));Text(model.text("disk.estimateNotice"))
                        detail("disk.important",disk.availableForImportantUse);detail("disk.purgeable",disk.purgeable);detail("disk.snapshots",disk.snapshots)
                        Text(model.dateText(disk.date)).font(.caption)
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(.top,8)
                }
            }
        }
    }
    private func capacity(_ key:String,_ bytes:Int64)->some View {
        VStack(alignment:.leading,spacing:5){Text(model.text(key)).foregroundStyle(.secondary);Text(model.capacityText(bytes)).font(.title.bold()).monospacedDigit()}.accessibilityElement(children:.combine)
    }
    private func detail(_ key:String,_ bytes:Int64?)->some View {Text(model.text(key)+": "+(bytes.map(model.capacityText) ?? model.text("unavailable")))}
}
