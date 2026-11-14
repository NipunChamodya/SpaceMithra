import SwiftUI

/// Binary treemap uses actual scanned sizes and has a text alternative below it.
struct StorageMap: View {
    let records: [FileRecord]
    @ObservedObject var model: AppModel
    var body: some View {
        let items = Array(records.filter { $0.logical > 0 }.prefix(12))
        VStack(alignment: .leading) {
            GeometryReader { geometry in
                let cells = tiles(items, in: CGRect(origin: .zero, size: geometry.size))
                ZStack(alignment: .topLeading) {
                    ForEach(Array(cells.enumerated()), id: \.element.file.path) { index, cell in
                        Button { navigate(cell.file) } label: {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(hue: Double(index) / 14, saturation: 0.65, brightness: 0.45))
                                .overlay {
                                    if cell.rect.width > 70 && cell.rect.height > 35 {
                                        VStack { Text(cell.file.name).lineLimit(2); Text(model.byteText(cell.file.logical)).font(.caption2) }
                                            .font(.caption).foregroundStyle(.white).padding(6)
                                    }
                                }
                        }.buttonStyle(.plain)
                            .frame(width: max(0, cell.rect.width - 3), height: max(0, cell.rect.height - 3))
                            .offset(x: cell.rect.minX, y: cell.rect.minY)
                            .accessibilityLabel(cell.file.name + ", " + model.byteText(cell.file.logical))
                            .help(cell.file.path + " · " + model.byteText(cell.file.logical))
                    }
                }
            }.frame(height: 220)
            ForEach(items) { file in
                Button { navigate(file) } label: {
                    HStack { Text(file.name); Spacer(); Text(model.byteText(file.logical)) }
                }.buttonStyle(.plain).font(.caption)
            }
        }.padding(12)
    }
    private func navigate(_ file: FileRecord) {
        if file.isDirectory { model.navigate(file.path) }
        else { model.selection = file.path; model.section = "explorer" }
    }
    private struct Tile { let file: FileRecord; let rect: CGRect }
    private func tiles(_ files: [FileRecord], in rect: CGRect) -> [Tile] {
        guard let first = files.first else { return [] }
        if files.count == 1 { return [Tile(file: first, rect: rect)] }
        let total = files.reduce(Double(0)) { $0 + Double($1.logical) }
        var split = 1, subtotal = Double(first.logical)
        while split < files.count - 1 && subtotal < total / 2 {
            subtotal += Double(files[split].logical); split += 1
        }
        let fraction = subtotal / max(1, total)
        let a: CGRect, b: CGRect
        if rect.width >= rect.height {
            a = CGRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height)
            b = CGRect(x: a.maxX, y: rect.minY, width: rect.width - a.width, height: rect.height)
        } else {
            a = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * fraction)
            b = CGRect(x: rect.minX, y: a.maxY, width: rect.width, height: rect.height - a.height)
        }
        return tiles(Array(files.prefix(split)), in: a) + tiles(Array(files.dropFirst(split)), in: b)
    }
}
