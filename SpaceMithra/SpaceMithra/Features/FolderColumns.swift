import SwiftUI

struct FolderColumns: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(model.columns, id: \.0) { path, children in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(path == "/" ? model.startupDisk?.name ?? model.text("disk.startup") : URL(fileURLWithPath:path).lastPathComponent).font(.caption.bold()).padding(.horizontal, 8)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(children) { file in
                                    Button { model.navigate(file.path) } label: {
                                        HStack {
                                            Image(systemName: "folder").foregroundStyle(.blue)
                                            Text(file.name).lineLimit(1)
                                            Spacer()
                                            Text(model.byteText(file.logical)).font(.caption2).foregroundStyle(.secondary)
                                            Image(systemName: "chevron.right").font(.caption2)
                                        }.padding(5).contentShape(Rectangle())
                                    }.buttonStyle(.plain).help(file.path)
                                }
                            }
                        }
                    }.frame(width: 245)
                    Divider()
                }
            }.padding(.vertical, 8)
        }.accessibilityLabel(model.text("explorer"))
    }
}
