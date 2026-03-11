import SwiftUI

enum CalendarDayStatus: Equatable {
    case empty
    case available(Int)
    case selected(Int)

    var dayNumber: Int? {
        switch self {
        case .empty: return nil
        case .available(let n): return n
        case .selected(let n): return n
        }
    }

    var isSelected: Bool {
        if case .selected = self { return true }
        return false
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

struct CalendarCellView: View {
    let status: CalendarDayStatus

    var body: some View {
        ZStack {
            if status.isEmpty {
                // Keep grid spacing consistent with a transparent placeholder
                Color.clear
                    .frame(height: 42)
            } else {
                let selected = status.isSelected
                let number   = status.dayNumber ?? 0

                Text("\(number)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected ? AppTheme.primary : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selected ? AppTheme.primary.opacity(0.0) : AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: selected ? AppTheme.primary.opacity(0.25) : Color.black.opacity(0.04),
                            radius: selected ? 6 : 4, x: 0, y: selected ? 4 : 2)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 12) {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
            ForEach(0..<35, id: \.self) { idx in
                let status: CalendarDayStatus = {
                    switch idx {
                    case 0..<5: return .empty
                    case 5:     return .available(1)
                    case 6:     return .available(2)
                    case 7:     return .available(3)
                    case 8:     return .available(4)
                    case 9:     return .available(5)
                    case 10:    return .available(6)
                    case 11:    return .available(7)
                    case 12:    return .available(8)
                    case 13:    return .available(9)
                    case 14:    return .available(10)
                    case 15:    return .available(11)
                    case 16:    return .available(12)
                    case 17:    return .available(13)
                    case 18:    return .available(14)
                    case 19:    return .available(15)
                    case 20:    return .available(16)
                    case 21:    return .available(17)
                    case 22:    return .available(18)
                    case 23:    return .available(19)
                    case 24:    return .selected(20)
                    case 25:    return .available(21)
                    case 26:    return .available(22)
                    case 27:    return .available(23)
                    case 28:    return .available(24)
                    case 29:    return .available(25)
                    case 30:    return .available(26)
                    case 31:    return .available(27)
                    case 32:    return .available(28)
                    case 33:    return .available(29)
                    case 34:    return .empty
                    default:    return .empty
                    }
                }()
                CalendarCellView(status: status)
            }
        }
        .padding(.horizontal, 16)
    }
    .padding()
    .background(AppTheme.background)
}
