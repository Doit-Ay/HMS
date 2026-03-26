import SwiftUI

// MARK: - Chip Color Set
private struct ChipColors {
    let text: Color
    let subtext: Color
    let background: Color
    let border: Color
    let shadow: Color
}

// MARK: - Slot Chip Label (extracted to avoid type-checker timeout)
private struct SlotChipLabel: View {
    let startText: String
    let endText: String
    let isSelected: Bool
    let showBadge: Bool
    let colors: ChipColors

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Text(startText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(endText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(colors.subtext)
            }
            .foregroundColor(colors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.background)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colors.border, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: colors.shadow, radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 3 : 1)
            .scaleEffect(isSelected ? 1.03 : 1.0)

            if showBadge {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white).frame(width: 12, height: 12))
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Slot Picker Grid View
// Replaces TimeRangePickerView — shows the doctor's actual 30-min slots as selectable chips.
struct SlotPickerGridView: View {
    let slots: [(start: String, end: String, isBooked: Bool)]
    @Binding var selectedSlotKeys: Set<String>
    var isLoading: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private func slotKey(start: String, end: String) -> String {
        "\(start)-\(end)"
    }

    private func formatTime(_ time: String) -> String {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return time }
        let hour = parts[0]
        let minute = parts[1]
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func chipColors(isBooked: Bool, isSelected: Bool) -> ChipColors {
        let isBookedAndSelected = isBooked && isSelected
        return ChipColors(
            text: isBookedAndSelected ? .red
                : isBooked ? Color(hex: "#6366F1")
                : isSelected ? .orange
                : AppTheme.textPrimary,
            subtext: isBookedAndSelected ? Color.red.opacity(0.8)
                : isBooked ? Color(hex: "#6366F1").opacity(0.7)
                : isSelected ? Color.orange.opacity(0.8)
                : AppTheme.textSecondary.opacity(0.6),
            background: isBookedAndSelected ? Color.red.opacity(0.10)
                : isBooked ? Color(hex: "#6366F1").opacity(0.08)
                : isSelected ? Color.orange.opacity(0.12)
                : AppTheme.cardSurface,
            border: isBookedAndSelected ? Color.red.opacity(0.5)
                : isBooked ? Color(hex: "#6366F1").opacity(0.3)
                : isSelected ? Color.orange.opacity(0.5)
                : Color.gray.opacity(0.15),
            shadow: isBookedAndSelected ? Color.red.opacity(0.15)
                : isSelected ? Color.orange.opacity(0.15)
                : Color.black.opacity(0.03)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.orange)
                Text("Select Unavailable Slots")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading slots...")
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if slots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.4))
                    Text("No slots available for this date")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(slots.indices, id: \.self) { index in
                        let slot = slots[index]
                        let key = slotKey(start: slot.start, end: slot.end)
                        let isSelected = selectedSlotKeys.contains(key)
                        let colors = chipColors(isBooked: slot.isBooked, isSelected: isSelected)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isSelected {
                                    selectedSlotKeys.remove(key)
                                } else {
                                    selectedSlotKeys.insert(key)
                                }
                            }
                        } label: {
                            SlotChipLabel(
                                startText: formatTime(slot.start),
                                endText: formatTime(slot.end),
                                isSelected: isSelected,
                                showBadge: slot.isBooked && isSelected,
                                colors: colors
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Summary
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.7))
                    Text(selectedSlotKeys.isEmpty
                         ? "Tap slots to mark as unavailable"
                         : "\(selectedSlotKeys.count) slot\(selectedSlotKeys.count == 1 ? "" : "s") marked unavailable")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)

                // Legend
                HStack(spacing: 12) {
                    legendItem(color: Color.orange, label: "Unavailable")
                    legendItem(color: Color(hex: "#6366F1"), label: "Booked")
                    legendItem(color: Color.red, label: "Will Cancel")
                }
                .padding(.top, 4)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        SlotPickerGridView(
            slots: [
                (start: "09:00", end: "09:30", isBooked: false),
                (start: "09:30", end: "10:00", isBooked: false),
                (start: "10:00", end: "10:30", isBooked: true),
                (start: "10:30", end: "11:00", isBooked: false),
                (start: "11:00", end: "11:30", isBooked: false),
                (start: "11:30", end: "12:00", isBooked: false)
            ],
            selectedSlotKeys: .constant(Set(["09:00-09:30", "11:00-11:30"]))
        )
        .padding()
    }
}
