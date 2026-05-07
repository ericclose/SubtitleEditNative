import SwiftUI

struct FixResultsView: View {
    let count: Int
    let logLines: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fix Common Errors").font(.headline)
                    Text("\(count) errors fixed").font(.subheadline).foregroundColor(.green)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.black.opacity(0.1))
            
            Divider()
            
            // Log Area
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                                .padding(.top, 2)
                            
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                        
                        Divider().opacity(0.3)
                    }
                }
                .padding()
            }
            .background(Color.white.opacity(0.02))
        }
        .frame(width: 500, height: 400)
    }
}
