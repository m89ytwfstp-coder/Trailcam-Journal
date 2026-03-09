//
//  BucketListTabView.swift
//  Trailcam Journal
//

import SwiftUI

struct BucketListTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AppHeader(
                        title: "Bucket List",
                        subtitle: "Unlock species — first sighting date"
                    )

                    BucketListView()
                        .padding(.top, 4)

                    Spacer(minLength: 20)
                }
                .padding(.top, 2)
            }
            .appScreenBackground()
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
    }
}
