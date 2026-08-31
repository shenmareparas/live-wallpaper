import Foundation

enum EngineStatus: Equatable {
    case active
    case manualPaused
    case obscured
    case lowPower
    case idle
    
    var title: String {
        switch self {
        case .active: return "ENGINE ACTIVE"
        case .manualPaused: return "ENGINE PAUSED"
        case .obscured: return "DESKTOP OBSCURED"
        case .lowPower: return "BATTERY SAVER (ECO)"
        case .idle: return "NO WALLPAPER SELECTED"
        }
    }
    
    var subtitle: String {
        switch self {
        case .active: return "Rendering high-efficiency HEVC hardware video stream smoothly."
        case .manualPaused: return "Video playback is manually paused by user."
        case .obscured: return "Desktop is covered by active windows. Playback paused to save GPU resources."
        case .lowPower: return "Low Power Mode active. Engine paused to preserve battery."
        case .idle: return "Select or drop a video to activate dynamic desktop wallpaper."
        }
    }
}
