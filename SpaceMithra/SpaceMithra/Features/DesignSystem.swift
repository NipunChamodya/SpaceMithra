import SwiftUI

struct StorageSurface<Content:View>:View {
    @Environment(\.colorSchemeContrast) private var contrast
    private let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    var body: some View {
        content.padding(20).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).stroke(Color.primary.opacity(contrast == .increased ? 0.55:0.12)))
    }
}
struct StorageIllustration:View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius:36).fill(Color.accentColor.opacity(0.10)).frame(width:174,height:154)
            Image(systemName:"internaldrive.fill").font(.system(size:82,weight:.light)).foregroundStyle(Color.accentColor)
            Image(systemName:"leaf.fill").font(.system(size:37)).foregroundStyle(.green)
                .padding(11).background(Color(nsColor:.windowBackgroundColor),in:Circle()).offset(x:65,y:-48)
        }.accessibilityHidden(true)
    }
}
struct StorageEmptyState:View {
    let icon:String
    let title:String
    let message:String
    var body: some View {
        VStack(spacing:14){Image(systemName:icon).font(.system(size:44)).foregroundStyle(Color.accentColor);Text(title).font(.title2.bold());Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)}
            .padding(32).frame(maxWidth:560)
    }
}
