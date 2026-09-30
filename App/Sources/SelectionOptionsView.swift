import SwiftUI

struct SelectionOptionsView: View {
    @Bindable var model: ClipperModel
    @Environment(\.dismiss) private var dismiss

    private var configuration: RequestyConfiguration? { try? RequestyConfiguration() }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Clip selection") {
                    Picker("Select with", selection: $model.selectionOptions.provider) {
                        ForEach(SelectionOptions.Provider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    if model.selectionOptions.provider == .local {
                        Text("Use the original Clips model. Transcription, selection and titles run on this Mac.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Only the transcript and your preferences are sent through Requesty to OpenAI. Voz, titles, video preview and export stay on this Mac.")
                            .foregroundStyle(.secondary)
                    }
                }
                if model.selectionOptions.provider == .requesty {
                    Section("Short clips") {
                        Stepper("Up to \(model.selectionOptions.count) clips", value: $model.selectionOptions.count, in: 1...10)
                        LabeledContent("Maximum length", value: "\(Int(model.selectionOptions.maximumDuration)) seconds")
                        Slider(value: $model.selectionOptions.maximumDuration, in: 10...60, step: 5)
                            .accessibilityLabel("Maximum clip duration")
                        Picker("Focus", selection: $model.selectionOptions.focus) {
                            ForEach(SelectionOptions.Focus.allCases) { focus in
                                Text(focus.rawValue).tag(focus)
                            }
                        }
                        Text("Complete thoughts and context take priority. Bold statements keep the speaker's meaning and qualifications.")
                            .font(.callout).foregroundStyle(.secondary)
                        TextField("Additional instructions", text: $model.selectionOptions.instructions, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section("OpenAI model") {
                        TextField("Model for this session", text: $model.selectionOptions.model,
                                  prompt: Text(configuration?.model ?? "Use the 1Password default"))
                        Text("Leave empty to use REQUESTY_MODEL from 1Password. Enter an OpenAI model ID available to your Requesty key, such as openai/gpt-5.")
                            .font(.callout).foregroundStyle(.secondary)
                        if let configuration {
                            LabeledContent("Requesty", value: configuration.baseURL.host ?? "")
                        } else {
                            Label("Start the app through the project's 1Password launcher to enable Requesty.", systemImage: "key")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !model.sentences.isEmpty {
                    Section {
                        Text("Selecting again reuses this video's transcript. A successful search replaces the clips and any sentence edits; if it fails, your current clips remain.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(!canEdit)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if !model.sentences.isEmpty {
                    Button("Select Again") {
                        model.selectAgain()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSelectAgain || !requestyIsReady)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(width: 540, height: model.selectionOptions.provider == .requesty ? 650 : 340)
    }

    private var canEdit: Bool {
        if case .idle = model.phase { return true }
        return model.canSelectAgain
    }

    private var requestyIsReady: Bool {
        model.selectionOptions.provider == .local || configuration != nil
    }
}
