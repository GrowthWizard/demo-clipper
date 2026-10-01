import AVFoundation
import Foundation
import Testing
import Transcript

@Suite("Requesty export duration")
struct RequestyExportTests {
    @Test("Checks the encoded file and removes an export that exceeds its cap", arguments: [true, false])
    func checksWrittenDuration(allowed: Bool) async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appending(path: "source.wav")
        let destination = folder.appending(path: "clip.m4a")
        try silentWave(seconds: 3).write(to: source)

        if allowed {
            let written = try await Cutting.write(source, ranges: [TimeRange(start: 0, end: 2)],
                                                 to: destination, maximumDuration: 3)
            let duration = try await AVURLAsset(url: written).load(.duration).seconds
            #expect(duration > 0 && duration <= 3)
            #expect(FileManager.default.fileExists(atPath: written.path))
        } else {
            await #expect(throws: RequestySelectionError.self) {
                try await Cutting.write(source, ranges: [TimeRange(start: 0, end: 2)],
                                        to: destination, maximumDuration: 1)
            }
            #expect(!FileManager.default.fileExists(atPath: destination.path))
            #expect(FileManager.default.fileExists(atPath: source.path))
        }
    }

    // A PCM fixture generated in memory keeps the test independent of ffmpeg,
    // downloads, model caches and the user's recordings.
    private func silentWave(seconds: Int) -> Data {
        let samples = UInt32(seconds * 8_000 * 2)
        var wave = Data()
        func text(_ value: String) { wave.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wave.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(36) + samples); text("WAVEfmt ")
        integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1))
        integer(UInt32(8_000)); integer(UInt32(16_000))
        integer(UInt16(2)); integer(UInt16(16)); text("data"); integer(samples)
        wave.append(Data(count: Int(samples)))
        return wave
    }
}
