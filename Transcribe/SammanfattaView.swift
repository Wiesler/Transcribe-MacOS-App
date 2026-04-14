import SwiftUI
import AppKit

// MARK: - Meeting Prompt Model

struct MeetingPrompt: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let systemIcon: String
    let prompt: String

    static let all: [MeetingPrompt] = [
        MeetingPrompt(
            name: "Mötesöversikt",
            description: "Kortfattad A4-sammanfattning",
            systemIcon: "doc.text",
            prompt: """
            Du är en professionell mötesammanfattare. Skapa en kortfattad överskådlig sammanfattning av mötet på max en A4-sida.

            Strukturera svaret så här:

            MÖTESINFO
            Mötestyp och datum om det framgår av transkriptionen.

            SYFTE
            Huvudsyftet med mötet i 1–2 meningar.

            HUVUDPUNKTER
            De 3–5 viktigaste diskussionspunkterna som korta stödpunkter.

            BESLUT
            Numrerad lista med alla beslut som fattades.

            NÄSTA STEG
            Max 3 punkter om vad som händer härnäst.

            Håll språket formellt men koncist. Fokusera enbart på väsentlig information.
            """
        ),
        MeetingPrompt(
            name: "Detaljerat protokoll",
            description: "Formellt mötesprotokoll",
            systemIcon: "doc.richtext",
            prompt: """
            Du är en professionell protokollförare. Skapa ett komplett och detaljerat mötesprotokoll.

            Strukturera protokollet med dessa sektioner:

            MÖTESINFO
            Datum, tid, mötestyp, ordförande och deltagare (om de framgår).

            DAGORDNING OCH DISKUSSIONER
            För varje diskussionspunkt: rubrik, huvudargument, eventuella meningsskiljaktigheter och slutsats.

            FATTADE BESLUT
            Numrerade beslut med innehåll, beslutsfattare och implementeringsdatum om sådant nämns.

            ÅTGÄRDSPUNKTER
            Tabell med kolumnerna: Åtgärd | Ansvarig | Deadline | Prioritet

            RISKER OCH BEROENDEN
            Identifierade risker eller blockeringar.

            NÄSTA MÖTE
            Föreslaget datum och fokusområden om de nämndes.

            Var noggrann och inkludera alla relevanta detaljer. Behåll ett professionellt språk.
            """
        ),
        MeetingPrompt(
            name: "Deltagaranalys",
            description: "Vem sa vad och vem bidrog",
            systemIcon: "person.3",
            prompt: """
            Du är en analytiker av mötesdiskussioner. Analysera vem som sa vad och vilka bidrag varje deltagare gjorde.

            För varje identifierad deltagare, dokumentera:
            - Namn och roll (om det framgår)
            - Huvudsakliga poänger och uttalanden (3–5 punkter)
            - Tilldelade ansvarsområden eller åtgärder
            - Hur personen påverkade diskussionen

            Avsluta med en sammanfattad statistik:
            - Mest bidragande deltagare
            - Identifierade beslutsfattare
            - Eventuella oenigheter eller motsättningar

            Analysera på ett objektivt och neutralt sätt baserat enbart på vad som faktiskt sägs i transkriptionen.
            """
        ),
        MeetingPrompt(
            name: "Beslutslogg",
            description: "Vad beslöts och varför",
            systemIcon: "checkmark.seal",
            prompt: """
            Du är en beslutslogg-expert. Dokumentera alla beslut som fattades under mötet.

            För varje beslut, dokumentera:

            BESLUT NR: [nummer]
            TITEL: Kort beskrivande titel
            BESLUTET: Fullständig beskrivning av vad som beslöts
            BAKGRUND: Varför behövdes beslutet och vilka argument presenterades
            BESLUTSFATTARE: Vem fattade beslutet och om det var enhälligt
            KONSEKVENSER: Vilka effekter beslutet kommer att ha
            IMPLEMENTERING: Hur och när beslutet ska genomföras
            ALTERNATIV: Eventuella alternativ som diskuterades men valdes bort

            Avsluta med en numrerad snabblista över alla beslut för enkel överblick.

            Dokumentera alla beslut objektivt och gör det enkelt att förstå vad som är bindande.
            """
        ),
        MeetingPrompt(
            name: "Uppföljningsplan",
            description: "Åtgärder, ansvar och deadlines",
            systemIcon: "calendar.badge.clock",
            prompt: """
            Du är en projektplanerare. Skapa en strukturerad uppföljningsplan baserad på mötet.

            OMEDELBAR UPPFÖLJNING (nästa 48 timmar)
            Vad måste göras omedelbart, i prioritetsordning med ansvarig person.

            ÅTGÄRDSTABELL
            Tabell med kolumnerna: Nr | Åtgärd | Ansvarig | Deadline | Prioritet | Beroenden

            MILSTOLPAR
            Viktiga milstolpe-datum fram till nästa möte eller projektmål.

            RISKER OCH BLOCKERARE
            Identifierade risker med föreslagen mitigering.

            NÄSTA MÖTE
            Föreslaget datum, förberedelser och fokusområden.

            Skapa en praktisk och handlingsbar plan som gör det tydligt vad var och en behöver göra.
            """
        )
    ]
}

// MARK: - SammanfattaView

struct SammanfattaView: View {
    let transcribedText: String

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var selectedPrompt: MeetingPrompt = MeetingPrompt.all[0]
    @State private var result: String = ""
    @State private var isProcessing = false
    @State private var llmTask: Task<Void, Never>?
    @State private var copyConfirmed = false

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
                .frame(width: 260)
            Rectangle()
                .fill(Color.borderLight)
                .frame(width: 1)
            rightPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceBackground)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    appState.showSammanfattaView = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Sammanfatta")
        .toolbar(removing: .title)
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Välj typ")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)

            // Prompt cards
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(MeetingPrompt.all) { prompt in
                        promptCard(prompt)
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()

            // Model status indicator
            if settingsManager.selectedOllamaModel.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("Ingen modell vald — konfigurera i Inställningar")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                    Text(settingsManager.selectedOllamaModel)
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Applicera button
            Button(action: applicera) {
                HStack(spacing: 8) {
                    if isProcessing {
                        AccentSpinner(size: 14, lineWidth: 2)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(isProcessing ? "Bearbetar..." : "Applicera")
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(applicerDisabled ? .textTertiary : .white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(applicerDisabled
                              ? Color.textTertiary.opacity(0.15)
                              : LinearGradient.accentGradient)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(applicerDisabled)
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(Color.sidebarBackground)
    }

    private var applicerDisabled: Bool {
        isProcessing || settingsManager.selectedOllamaModel.isEmpty
    }

    @ViewBuilder
    private func promptCard(_ prompt: MeetingPrompt) -> some View {
        let isSelected = selectedPrompt.id == prompt.id
        Button(action: {
            selectedPrompt = prompt
        }) {
            HStack(spacing: 12) {
                Image(systemName: prompt.systemIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? LinearGradient.accentGradient : LinearGradient(colors: [Color.textSecondary], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .textPrimary : .textSecondary)
                    Text(prompt.description)
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.primaryAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primaryAccent.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.primaryAccent.opacity(0.4) : Color.borderLight, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(spacing: 0) {
            // Result header
            HStack {
                Text("Resultat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)

                if isProcessing {
                    AccentSpinner(size: 16, lineWidth: 2)
                }

                Spacer()

                if !result.isEmpty {
                    Button(action: copyResult) {
                        HStack(spacing: 5) {
                            Image(systemName: copyConfirmed ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13))
                            Text(copyConfirmed ? "Kopierad" : "Kopiera")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primaryAccent, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: saveResult) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 13))
                            Text("Spara")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primaryAccent, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 1)

            // Result content
            if result.isEmpty && !isProcessing {
                emptyState
            } else {
                MarkdownTextView(
                    markdown: result,
                    fontSize: 14,
                    isStreaming: isProcessing
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            Spacer(minLength: 0)

            // Chat placeholder (reserved for future feature)
            chatPlaceholder
        }
        .background(Color.surfaceBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(.textTertiary)
            Text("Välj en sammanfattningstyp och tryck på Applicera")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var chatPlaceholder: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
                Text("Chatt")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textTertiary)
                Text("— kommer snart")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary.opacity(0.6))
            }
            Text("Ställ följdfrågor direkt om transkriptionen")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func applicera() {
        guard !settingsManager.selectedOllamaModel.isEmpty else { return }

        llmTask?.cancel()
        result = ""
        isProcessing = true

        let systemPrompt = selectedPrompt.prompt
        let userMessage = transcribedText
        let model = settingsManager.selectedOllamaModel
        let host = settingsManager.ollamaHost

        llmTask = Task {
            let llmService = LLMService()
            do {
                let stream = llmService.streamCompletion(
                    systemPrompt: systemPrompt,
                    userMessage: userMessage,
                    provider: .ollama,
                    model: model,
                    ollamaHost: host
                )
                for try await token in stream {
                    await MainActor.run { result += token }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        result += "\n\n[Fel: \(error.localizedDescription)]"
                    }
                }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    private func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
        copyConfirmed = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { copyConfirmed = false }
        }
    }

    private func saveResult() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(selectedPrompt.name).txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? result.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
