import SwiftUI

struct SelectionOptionsView: View {
    @Bindable var model: ClipperModel
    @Environment(\.dismiss) private var dismiss

    private var configuration: RequestyConfiguration? { model.requestyConfiguration }

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
                        Text("GLM finds candidates, reviews their content and drafts titles. Only the transcript and your preferences are sent through Requesty. Transcription, video preview and export stay on this Mac.")
                            .foregroundStyle(.secondary)
                    }
                }
                if model.selectionOptions.provider == .requesty {
                    Section("Requesty access") {
                        SecureField("Requesty API key", text: $model.requestyCredentials.apiKey)
                            .accessibilityLabel("Requesty API key")
                        TextField("GLM 5.3 Flash model", text: $model.requestyCredentials.model)
                        TextField("Requesty router", text: $model.requestyCredentials.baseURL)
                        Toggle("Remember access in macOS Keychain", isOn: $model.remembersRequestyAccess)
                        Text(model.remembersRequestyAccess
                             ? "The key, model and router are saved in this app's encrypted login Keychain item on this Mac."
                             : "The key stays in memory until you quit the app. No 1Password mount is needed.")
                            .font(.callout).foregroundStyle(.secondary)
                        if configuration == nil {
                            Text("Enter your Requesty key and an allowed GLM 5.3 Flash ID. The default glm-5.3-flash@eu uses EU providers.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Section("Content brief") {
                        Picker("Destination", selection: $model.selectionOptions.destination) {
                            ForEach(SelectionOptions.Destination.allCases) { destination in
                                Text(destination.rawValue).tag(destination)
                            }
                        }
                        TextField("Audience", text: $model.selectionOptions.audience, axis: .vertical)
                            .lineLimit(2...3)
                        TextField("Content goal", text: $model.selectionOptions.contentGoal, axis: .vertical)
                            .lineLimit(2...3)
                        Text("Only candidates that pass the editorial review become clips. Fewer strong clips are preferred over filling the requested count.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
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
                }
                if let problem = model.requestyAccessProblem {
                    Section {
                        Text(problem).font(.callout).foregroundStyle(.red)
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
                Button("Done") {
                    if model.saveRequestyAccess() { dismiss() }
                }
                    .keyboardShortcut(.cancelAction)
                if !model.sentences.isEmpty {
                    Button("Select Again") {
                        guard model.saveRequestyAccess() else { return }
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
        .frame(width: 560, height: model.selectionOptions.provider == .requesty ? 760 : 340)
    }

    private var canEdit: Bool {
        if case .idle = model.phase { return true }
        return model.canSelectAgain
    }

    private var requestyIsReady: Bool {
        model.selectionOptions.provider == .local || (configuration != nil && (try? model.selectionOptions.validate()) != nil)
    }
}
