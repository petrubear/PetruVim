import Foundation

final class DistributedNotifAdapter: NotificationPort {
    static let modeChangeNotification = Notification.Name("com.petru.PetruVim.modeChange")
    static let modeKey = "mode"

    func postModeChange(_ mode: VimMode) {
        DistributedNotificationCenter.default().postNotificationName(
            Self.modeChangeNotification,
            object: nil,
            userInfo: [Self.modeKey: mode.notificationString],
            deliverImmediately: true
        )
    }
}

private extension VimMode {
    var notificationString: String {
        switch self {
        case .normal: return "N"
        case .insert: return "I"
        case .visual: return "V"
        }
    }
}
