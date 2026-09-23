import AdjustSdk
import AdSupport
import AppTrackingTransparency
import UIKit

private enum AdjustStorage {
    static let attribution = "lastAdjustAttribution"
    static let idfa = "idfa"
}

final class AdjustAttributionHandler: NSObject, AdjustDelegate {
    func adjustAttributionChanged(_ attribution: ADJAttribution?) {
        guard let attribution else { return }

        if #available(iOS 14, *),
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            return
        }

        guard let json = attribution.jsonResponse,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let value = String(data: data, encoding: .utf8) else {
            UserDefaults.standard.removeObject(forKey: AdjustStorage.attribution)
            return
        }

        UserDefaults.standard.set(value, forKey: AdjustStorage.attribution)
    }
}

enum AdjustIntegration {
    @MainActor
    static func requestTrackingPermissionAndStoreIDFA() async -> String {
        await waitUntilApplicationIsActive()

        guard #available(iOS 14.5, *) else {
            return storeIDFA(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
        }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        if currentStatus == .notDetermined {
            _ = await Adjust.requestAppTrackingAuthorization()
        }

        return storeIDFA(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
    }

    @MainActor
    private static func waitUntilApplicationIsActive() async {
        // Give the push-permission dialog time to appear before checking state.
        try? await Task.sleep(nanoseconds: 500_000_000)

        while UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Let the previous system dialog finish dismissing before requesting ATT.
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    static func storedIDFA() -> String {
        if let idfa = UserDefaults.standard.string(forKey: AdjustStorage.idfa), !idfa.isEmpty {
            return idfa
        }
        return storeIDFA(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
    }

    @discardableResult
    private static func storeIDFA(_ idfa: String) -> String {
        UserDefaults.standard.set(idfa, forKey: AdjustStorage.idfa)
        return idfa
    }

    static func adid() async -> String {
        await Adjust.adid() ?? ""
    }

    static func attribution(upToSeconds seconds: Int = 5) async -> [String: Any] {
        for _ in 0..<seconds {
            if let value = UserDefaults.standard.string(forKey: AdjustStorage.attribution),
               !value.isEmpty {
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        guard let jsonString = UserDefaults.standard.string(forKey: AdjustStorage.attribution),
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return [
            "trackerToken": json["trackerToken"] as? String ?? "",
            "trackerName": json["trackerName"] as? String ?? "",
            "network": json["network"] as? String ?? "",
            "campaign": json["campaign"] as? String ?? "",
            "adgroup": json["adgroup"] as? String ?? "",
            "creative": json["creative"] as? String ?? "",
            "clickLabel": json["clickLabel"] as? String ?? "",
            "costType": json["costType"] as? String ?? "",
            "costAmount": json["costAmount"] as? Double ?? 0,
            "costCurrency": json["costCurrency"] as? String ?? "",
            "jsonResponse": jsonString
        ]
    }
}
