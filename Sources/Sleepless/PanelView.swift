import SwiftUI

struct PanelView: View {
    @Bindable var controller: SleepController
    var updates: UpdateChecker
    @FocusState private var switchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            mainTile
            if let note = controller.note {
                Label(note.text, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            footer
            if let version = updates.available {
                updatePill(version)
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(width: 330)
        .animation(.easeInOut(duration: 0.2), value: controller.note)
        .animation(.easeInOut(duration: 0.2), value: updates.available)
        // Otherwise the popover's first key view, the login checkbox, takes focus.
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didShowNotification)) { _ in
            switchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: CupGlyph.image(steaming: controller.isEnabled))
                .renderingMode(.template)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(controller.isEnabled ? Color.orange : Color.secondary)
                .frame(width: 44, height: 44)
                .glass(in: Circle(), tint: controller.isEnabled ? .orange : nil)
                .animation(.smooth(duration: 0.35), value: controller.isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sleepless")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(L(controller.isEnabled ? "status.on" : "status.off"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: controller.isEnabled)
            }
        }
    }

    private var mainTile: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(L("toggle.title"))
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Mouse clicks go to the whole tile; the switch itself takes keyboard focus (Space toggles).
            // The spinner takes the switch's place so the text never reflows.
            ZStack {
                Toggle(L("toggle.title"), isOn: Binding(
                    get: { controller.isEnabled },
                    set: { value in Task { await controller.setEnabled(value) } }
                ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(.orange)
                    .focused($switchFocused)
                    .opacity(controller.isBusy ? 0 : 1)
                if controller.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            .allowsHitTesting(false)
        }
        .padding(16)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { controller.toggle() }
        .glass(in: RoundedRectangle(cornerRadius: 22, style: .continuous),
               tint: controller.isEnabled ? .orange : nil,
               interactive: true)
        .animation(.smooth(duration: 0.35), value: controller.isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(L(controller.isEnabled ? "status.on" : "status.off"))
        .accessibilityAction { controller.toggle() }
    }

    private var footer: some View {
        HStack {
            Toggle(L("footer.openAtLogin"), isOn: Binding(
                get: { controller.opensAtLogin },
                set: { controller.setOpensAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.callout)

            Spacer()

            Button(L("footer.quit")) { NSApp.terminate(nil) }
                .glassButton()
                .keyboardShortcut("q")
        }
    }

    /// The whole pill is the button; it opens the site, where the installer is.
    private func updatePill(_ version: String) -> some View {
        Button { NSWorkspace.shared.open(UpdateChecker.site) } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.orange)
                Text(String(format: L("update.available"), version))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L("update.get"))
                    .fontWeight(.semibold)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glass(in: Capsule(), interactive: true)
    }
}

/// Liquid Glass on macOS 26+, translucent material before it.
private extension View {
    @ViewBuilder
    func glass(in shape: some Shape, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(
                Glass.regular.tint(tint?.opacity(0.35)).interactive(interactive),
                in: shape
            )
        } else {
            background(.regularMaterial, in: shape)
                .background((tint ?? .clear).opacity(0.25), in: shape)
        }
    }

    @ViewBuilder
    func glassButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}
