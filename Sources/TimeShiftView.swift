import SwiftUI

struct TimeShiftView: View {
    @Binding var milliseconds: Double
    var onApply: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Adjust All Times").font(.headline)
            
            HStack(spacing: 15) {
                Button(action: { milliseconds -= 100 }) { Image(systemName: "minus.circle") }
                
                TextField("", value: $milliseconds, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                
                Button(action: { milliseconds += 100 }) { Image(systemName: "plus.circle") }
            }
            
            Text("Milliseconds").font(.caption).foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                Button("-1 sec") { milliseconds -= 1000 }.buttonStyle(.bordered)
                Button("+1 sec") { milliseconds += 1000 }.buttonStyle(.bordered)
            }
            
            Divider()
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Apply") {
                    onApply(milliseconds)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
