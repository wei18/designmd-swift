// Example SwiftUI view consuming the generated `Theme`.
//
// `Theme` comes from Theme.swift, which is generated from DESIGN.md by:
//   designmd export DESIGN.md --format swift --out Theme.swift
//
// Every color / font / spacing / radius below traces back to a token in
// DESIGN.md — change the design there, regenerate, and this view follows.

import SwiftUI

struct TideCardView: View {
    let location: String
    let height: String   // e.g. "2.4 m"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(location)
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(Theme.Colors.primary)

            Text(height)
                .font(Theme.Typography.metric)        // SF Mono — tabular digits
                .foregroundStyle(Theme.Colors.onSurface)

            Button("Set Alert") { }
                .font(Theme.Typography.body)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.accent)       // the single tint
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }
}

#Preview {
    TideCardView(location: "High Tide", height: "2.4 m")
        .padding()
}
