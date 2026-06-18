import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechInputService {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case unavailable(String)
        case failed(String)
    }

    var state: State = .idle
    var transcript = ""

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var hasInputTap = false

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isListening: Bool {
        state == .listening
    }

    var isShowingError: Bool {
        switch state {
        case .failed, .unavailable:
            return true
        case .idle, .requestingPermission, .listening:
            return false
        }
    }

    var statusMessage: String? {
        switch state {
        case .idle:
            return nil
        case .requestingPermission:
            return "正在请求语音输入权限..."
        case .listening:
            return "正在听，识别结果会自动填入输入框"
        case .unavailable(let message), .failed(let message):
            return message
        }
    }

    func toggleListening() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        guard state != .requestingPermission else { return }

        transcript = ""
        state = .requestingPermission

        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable("这台设备暂时不能使用语音识别。")
            return
        }

        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            state = .failed("请在系统设置中允许语音识别权限。")
            return
        }

        let isMicrophoneAllowed = await requestMicrophonePermission()
        guard isMicrophoneAllowed else {
            state = .failed("请在系统设置中允许麦克风权限。")
            return
        }

        do {
            try startRecognition(with: recognizer)
            state = .listening
        } catch {
            cleanup(cancelTask: true, shouldDeactivateAudioSession: true)
            state = .failed("语音输入启动失败，请稍后再试。")
        }
    }

    func stop() {
        guard state == .listening || state == .requestingPermission else { return }

        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        stopAudioEngine()
        deactivateAudioSession()
        state = .idle
    }

    private func startRecognition(with recognizer: SFSpeechRecognizer) throws {
        cleanup(cancelTask: true, shouldDeactivateAudioSession: false)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasInputTap = true

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if result.isFinal {
                        self.cleanup(cancelTask: false, shouldDeactivateAudioSession: true)
                        self.state = .idle
                    }
                }

                if error != nil && self.state == .listening {
                    self.cleanup(cancelTask: false, shouldDeactivateAudioSession: true)
                    self.state = .failed("语音识别失败，请再试一次。")
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    private func cleanup(cancelTask: Bool, shouldDeactivateAudioSession: Bool) {
        stopAudioEngine()
        recognitionRequest?.endAudio()

        if cancelTask {
            recognitionTask?.cancel()
        }

        recognitionTask = nil
        recognitionRequest = nil

        if shouldDeactivateAudioSession {
            deactivateAudioSession()
        }
    }

    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
