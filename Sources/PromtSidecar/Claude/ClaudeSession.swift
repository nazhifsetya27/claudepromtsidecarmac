import Foundation

enum ClaudeSession {
    private static let sessionIdKey = "claude.sessionId"
    private static let sessionStartKey = "claude.sessionStartDate"

    static var sessionId: String? {
        get { UserDefaults.standard.string(forKey: sessionIdKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: sessionIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionIdKey)
            }
        }
    }

    private static var sessionStartDate: Date? {
        get { UserDefaults.standard.object(forKey: sessionStartKey) as? Date }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: sessionStartKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionStartKey)
            }
        }
    }

    static func ensureFreshDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if let start = sessionStartDate, Calendar.current.isDate(start, inSameDayAs: today) {
            return
        }
        sessionId = nil
        sessionStartDate = today
    }

    static func setSessionId(_ id: String) {
        sessionId = id
        if sessionStartDate == nil {
            sessionStartDate = Calendar.current.startOfDay(for: Date())
        }
    }
}
