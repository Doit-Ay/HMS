import SwiftUI

struct ProfileInfoField {
    let title: String
    var value: String
    let isEditable: Bool
    let keyboardType: UIKeyboardType
    // Optional array for dropdown options
    let options: [String]?
    
    init(title: String, value: String, isEditable: Bool = true, keyboardType: UIKeyboardType = .default, options: [String]? = nil) {
        self.title = title
        self.value = value
        self.isEditable = isEditable
        self.keyboardType = keyboardType
        self.options = options
    }
}

// A generic card that takes a title and a list of fields, and renders them in view or edit mode
struct ProfileInfoCard: View {
    let title: String
    @Binding var fields: [ProfileInfoField]
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. External Title
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.leading, 8)
            
            // 2. Main Card Box
            VStack(alignment: .leading, spacing: 16) {
                ForEach(0..<fields.count, id: \.self) { index in
                    if isEditing {
                        // EDIT MODE: Stacked title and input field
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fields[index].title)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            if !fields[index].isEditable {
                                // Locked field view
                                HStack {
                                    Text(fields[index].value)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textSecondary.opacity(0.5))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                            } else if let options = fields[index].options {
                                // Dropdown picker
                                Menu {
                                    ForEach(options, id: \.self) { option in
                                        Button(option) {
                                            fields[index].value = option
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(fields[index].value.isEmpty ? "Select..." : fields[index].value)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.primary)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.primary, lineWidth: 1)
                                    )
                                }
                            } else {
                                // Text input field
                                TextField("", text: $fields[index].value)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .keyboardType(fields[index].keyboardType)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(AppTheme.cardSurface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppTheme.primary, lineWidth: 1)
                                    )
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isEditing)
                    } else {
                        // VIEW MODE: Single horizontal line
                        VStack(spacing: 12) {
                            HStack(alignment: .top) {
                                Text(fields[index].title)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                                
                                Spacer()
                                
                                Text(fields[index].value)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            if index != fields.count - 1 {
                                Divider()
                                    .background(AppTheme.textSecondary.opacity(0.2))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(AppTheme.cardSurface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }
}

// Interactive preview wrapper
struct ProfileInfoCardPreview: View {
    @State private var isEditing = false
    @State private var fields = [
        ProfileInfoField(title: "Full Name", value: "Dr. Saif Ababon"),
        ProfileInfoField(title: "Doctor ID", value: "ID: 32145687", isEditable: false),
        ProfileInfoField(title: "Specialty", value: "Cardiologist", options: ["Cardiologist", "Neurologist", "Pediatrician"]),
        ProfileInfoField(title: "Phone", value: "+1 234 567 8900", keyboardType: .phonePad)
    ]
    
    var body: some View {
        VStack {
            Toggle("Edit Mode", isOn: $isEditing)
                .padding()
            
            ProfileInfoCard(
                title: "Personal Information",
                fields: $fields,
                isEditing: isEditing
            )
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview {
    ProfileInfoCardPreview()
}
