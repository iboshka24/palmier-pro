#if !os(macOS)
import Foundation

/// In-memory demo project served until project files load on all platforms.
enum DemoLibrary {
    static let timeline: Timeline? = {
        do {
            return try JSONDecoder().decode(Timeline.self, from: Data(json.utf8))
        } catch {
            Log.project.error("demo decode failed: \(Log.detail(error))")
            return nil
        }
    }()

    private static let json = """
    {
        "name": "Demo Project Timeline",
        "fps": 30,
        "width": 1920,
        "height": 1080,
        "tracks": [
            {
                "type": "video",
                "name": "V1",
                "clips": [
                    { "mediaRef": "intro.mp4", "mediaType": "video", "startFrame": 0, "durationFrames": 240 },
                    { "mediaRef": "scene-b.mp4", "mediaType": "video", "startFrame": 240, "durationFrames": 180 }
                ]
            },
            {
                "type": "audio",
                "name": "A1",
                "clips": [
                    { "mediaRef": "score.wav", "mediaType": "audio", "startFrame": 0, "durationFrames": 420 }
                ]
            },
            {
                "type": "text",
                "name": "T1",
                "clips": [
                    { "mediaRef": "Title", "mediaType": "text", "startFrame": 30, "durationFrames": 120, "textContent": "Palmier Port" }
                ]
            }
        ]
    }
    """
}
#endif
