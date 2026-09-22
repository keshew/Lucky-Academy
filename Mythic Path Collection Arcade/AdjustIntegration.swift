import AdjustSdk
import AdSupport
import AppTrackingTransparency

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
    static func requestTrackingPermissionAndStoreIDFA() async {
        guard #available(iOS 14.5, *) else {
            UserDefaults.standard.set(
                ASIdentifierManager.shared().advertisingIdentifier.uuidString,
                forKey: AdjustStorage.idfa
            )
            return
        }

        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        let status: UInt

        if currentStatus == .notDetermined {
            status = await Adjust.requestAppTrackingAuthorization()
        } else {
            status = UInt(currentStatus.rawValue)
        }

        let idfa = status == UInt(ATTrackingManager.AuthorizationStatus.authorized.rawValue)
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
            : ""
        UserDefaults.standard.set(idfa, forKey: AdjustStorage.idfa)
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
