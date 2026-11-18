import SwiftUI

// MARK: - Сведения о сессии

/// Карточка сессии: чем работает, где лежит, что можно сделать.
struct SessionSheet: View {
    @ObservedObject var store: ChatStore
    var onOpenWeb: () -> Void
    var onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            AuraBackground(intensity: 0.9)

            ScrollView {
                VStack(spacing: 14) {
                    grabber

                    if let session = store.currentSession {
                        titleBlock(session)
                        infoBlock(session)
                        agentBlock(session)
                        modelBlock(session)
                        actions(session)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 38, height: 4)
            .padding(.top, 10)
    }

    private func titleBlock(_ session: Session) -> some View {
        VStack(spacing: 6) {
            Text(session.displayTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Ink.primary)
                .multilineTextAlignment(.center)
            Text(session.projectName)
                .font(.system(size: 12.5))
                .foregroundStyle(Ink.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func infoBlock(_ session: Session) -> some View {
        VStack(spacing: 0) {
            row("Агент", session.agent ?? "по умолчанию", icon: "person.crop.circle")
            SoftDivider().opacity(0.4).padding(.leading, 44)
            row("Модель", modelName(session), icon: "cpu")
            SoftDivider().opacity(0.4).padding(.leading, 44)
            row("Папка", session.location?.directory ?? "—", icon: "folder")
        }
        .glass(radius: 20)
    }

    private func agentBlock(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Режим работы")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 7) {
                ForEach(store.agents, id: \.id) { agent in
                    let selected = (session.agent ?? "build") == agent.id
                    Button {
                        Haptic.select()
                        Task { await store.select(agent: agent) }
                        dismiss()
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundStyle(selected ? Ink.mint : Ink.tertiary.opacity(0.6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(agent.title)
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundStyle(Ink.primary)
                                if let description = agent.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Ink.tertiary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(selected ? Ink.mint.opacity(0.10) : Ink.raised.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(selected ? Ink.mint.opacity(0.3) : Color.white.opacity(0.06),
                                              lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 6)
    }

    private func modelBlock(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Модель для этой сессии")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.tertiary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 7) {
                ForEach(store.models.prefix(8), id: \.key) { model in
                    modelRow(model, current: session.model)
                }
            }
        }
        .padding(.top, 6)
    }

    private func modelRow(_ model: ModelInfo, current: Session.SessionModel?) -> some View {
        let selected = current.map {
            "\($0.providerID)/\($0.id)" == model.key
        } ?? false

        return Button {
            Haptic.select()
            Task { await store.select(model: model) }
            dismiss()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? Ink.azure : Ink.tertiary.opacity(0.6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.title)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                    Text(model.providerID)
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Ink.azure.opacity(0.12) : Ink.raised.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(selected ? Ink.azure.opacity(0.35) : Color.white.opacity(0.06),
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actions(_ session: Session) -> some View {
        VStack(spacing: 9) {
            Button {
                Haptic.tap()
                dismiss()
                onOpenWeb()
            } label: {
                Label("Открыть как на компьютере", systemImage: "display")
            }
            .buttonStyle(QuietButtonStyle())

            Button {
                Haptic.tap(.medium)
                if confirmingDelete {
                    Task {
                        await store.delete(session)
                        dismiss()
                        onDeleted()
                    }
                } else {
                    withAnimation(Motion.snappy) { confirmingDelete = true }
                }
            } label: {
                Label(confirmingDelete ? "Точно удалить?" : "Удалить сессию",
                      systemImage: "trash")
                    .foregroundStyle(confirmingDelete ? Ink.coral : Ink.coral.opacity(0.85))
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.top, 10)
    }

    private func row(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.tertiary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Ink.primary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func modelName(_ session: Session) -> String {
        guard let model = session.model else { return "по умолчанию" }
        return model.id
    }
}
