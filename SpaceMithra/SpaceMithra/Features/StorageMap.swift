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
                        StorageTileButton(
                            file: cell.file,
                            rect: cell.rect,
                            hue: Double(index) / 14,
                            sizeText: model.byteText(cell.file.logical)
                        ) { navigate(cell.file) }
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

/// Keep the interactive tile and its label as separate type-checking boundaries.
/// Older Swift compilers time out on the combined ForEach/Button/overlay expression.
private struct StorageTileButton: View {
    let file: FileRecord
    let rect: CGRect
    let hue: Double
    let sizeText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            StorageTileLabel(name: file.name, sizeText: sizeText, hue: hue,
                             showsText: rect.width > 70 && rect.height > 35)
        }
        .buttonStyle(.plain)
        .frame(width: max(0, rect.width - 3), height: max(0, rect.height - 3))
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityLabel(file.name + ", " + sizeText)
        .help(file.path + " · " + sizeText)
    }
}

private struct StorageTileLabel: View {
    let name: String
    let sizeText: String
    let hue: Double
    let showsText: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hue: hue, saturation: 0.65, brightness: 0.45))
            if showsText {
                VStack {
                    Text(name).lineLimit(2)
                    Text(sizeText).font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
            }
        }
    }
}
