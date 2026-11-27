import AppKit

enum ModelSelection {
    // File sizes from the ggml Whisper model repository on Hugging Face.
    private static let downloadBytes: [String: Int64] = [
        "tiny.en": 77_704_715, "tiny.en-q5_1": 32_166_155,
        "tiny": 77_691_713, "tiny-q5_1": 32_152_673,
        "base.en": 147_964_211, "base.en-q5_1": 59_721_011,
        "base": 147_951_465, "base-q5_1": 59_707_625,
        "small.en": 487_614_201, "small.en-q5_1": 190_098_681,
        "small": 487_601_967,
        "medium.en": 1_533_774_781, "medium.en-q5_0": 539_225_533,
        "medium": 1_533_763_059,
        "large-v3-turbo": 1_624_555_275, "large-v3-turbo-q8_0": 874_188_075,
        "large-v3-turbo-q5_0": 574_041_195, "large-v3": 3_095_033_483,
    ]

    static func label(for model: String) -> String {
        if Transcriber.modelExists(modelSize: model) {
            return "\(model) — " + NSLocalizedString("Installed", tableName: "GlobeModels", comment: "Model available locally")
        }
        guard let bytes = downloadBytes[model] else { return model }
        return "\(model) — " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal)
    }

    static func choose() -> String? {
        let models = ["tiny-q5_1", "base-q5_1"] + Config.supportedModels.filter {
            $0 != "tiny-q5_1" && $0 != "base-q5_1"
        }
        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 315, height: 28), pullsDown: false)
        picker.addItems(withTitles: models.map { model in
            let suffix = Config.isEnglishOnlyModel(model)
                ? " · " + NSLocalizedString("English only", tableName: "GlobeModels", comment: "Model language")
                : ""
            return label(for: model) + suffix
        })
        picker.selectItem(at: 0)
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Choose a dictation model", tableName: "GlobeModels", comment: "Model chooser title")
        alert.informativeText = NSLocalizedString(
            "Choose prompt", tableName: "GlobeModels",
            value: "The list shows how much data each model downloads. Choose tiny-q5_1 if mobile data is limited, or base-q5_1 for better recognition. Both support multiple languages. Installed models work offline.",
            comment: "How to choose a model with limited data"
        )
        alert.accessoryView = picker
        alert.addButton(withTitle: NSLocalizedString("Use this model", tableName: "GlobeModels", comment: "Confirm model"))
        alert.addButton(withTitle: NSLocalizedString("Later", tableName: "GlobeModels", comment: "Defer model selection"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return models[picker.indexOfSelectedItem]
    }
}
