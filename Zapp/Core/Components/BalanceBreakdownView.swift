import SwiftUI
import ZcashLightClientKit

struct BalanceBreakdownView: View {
    private enum SegmentType: Hashable {
        case shielded
        case transparent
    }

    private struct Segment: Identifiable {
        let type: SegmentType
        let title: String
        let value: Zatoshi
        let color: Color

        var id: SegmentType { type }
    }

    let shieldedSpendable: Zatoshi
    let transparent: Zatoshi

    var body: some View {
        let segments = makeSegments()

        VStack(alignment: .leading, spacing: ZapSpacing.sm) {
            if !segments.isEmpty {
                barView(segments: segments)
                legendView(segments: segments)
            } else {
                placeholderView
            }
        }
    }

    private func makeSegments() -> [Segment] {
        let shieldedAmount = max(0, shieldedSpendable.amount)
        let transparentAmount = max(0, transparent.amount)

        var segments: [Segment] = []

        if shieldedAmount > 0 {
            segments.append(
                Segment(
                    type: .shielded,
                    title: "Shielded (spendable)",
                    value: Zatoshi(shieldedAmount),
                    color: ZapColors.primary
                )
            )
        }

        if transparentAmount > 0 {
            segments.append(
                Segment(
                    type: .transparent,
                    title: "Transparent",
                    value: Zatoshi(transparentAmount),
                    color: Color(.systemGray4)
                )
            )
        }

        return segments
    }

    private func totalAmount(for segments: [Segment]) -> Int64 {
        segments.reduce(0) { partial, segment in
            partial + max(0, segment.value.amount)
        }
    }

    private func barView(segments: [Segment]) -> some View {
        GeometryReader { geometry in
            let total = max(1, totalAmount(for: segments))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ZapRadius.small)
                    .fill(Color(.systemGray6))

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        let width = CGFloat(max(0, segment.value.amount)) / CGFloat(total) * geometry.size.width

                        segment.color
                            .frame(width: width)
                            .frame(height: 12)
                            .contentShape(Rectangle())
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: ZapRadius.small))
            }
        }
        .frame(height: 12)
    }

    private func legendView(segments: [Segment]) -> some View {
        HStack(spacing: ZapSpacing.md) {
            ForEach(segments) { segment in
                HStack(spacing: ZapSpacing.xs) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 8, height: 8)

                    Text(segment.title)
                        .font(.caption)
                        .foregroundColor(ZapColors.textSecondary)
                }
            }
        }
    }

    private var placeholderView: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.xs) {
            RoundedRectangle(cornerRadius: ZapRadius.small)
                .fill(Color(.systemGray6))
                .frame(height: 12)

            Text("No funds yet")
                .font(.caption)
                .foregroundColor(ZapColors.textSecondary)
        }
    }
}
