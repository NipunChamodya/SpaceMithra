import SwiftUI

struct ErrorMessageView:View {
    @ObservedObject var model:AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Label(model.text("error"),systemImage:"exclamationmark.triangle").font(.title2.bold())
            Text(model.error ?? "").fixedSize(horizontal:false,vertical:true)
            if let details=model.errorDetails {
                DisclosureGroup(model.text("technicalDetails")){ScrollView{Text(details).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(maxHeight:180)}
            }
            HStack{Spacer();Button(model.text("ok")){model.error=nil;model.errorDetails=nil}.keyboardShortcut(.defaultAction)}
        }.padding(28).frame(width:520)
    }
}
