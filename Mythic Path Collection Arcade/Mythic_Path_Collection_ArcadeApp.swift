import SwiftUI
import FirebaseCore
import FirebaseMessaging
import AdjustSdk

private let adjustAppToken = "nwunxy3t0xds"

@main
struct MythicPathArcadeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
           Loading()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate  {
    static var orientationLock = UIInterfaceOrientationMask.all
    private let adjustAttributionHandler = AdjustAttributionHandler()

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true

        let adjustConfig = ADJConfig(appToken: adjustAppToken, environment: ADJEnvironmentProduction)
        adjustConfig?.delegate = adjustAttributionHandler
        Adjust.initSdk(adjustConfig)
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("did register 8989")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken)) 8989")
        
        if let fcmToken {
            UserDefaults.standard.set(fcmToken, forKey: "fcmToken")
        } else {
            UserDefaults.standard.set("null", forKey: "fcmToken")
        }
        
        NotificationCenter.default.post(Notification(name: NSNotification.Name("tokenReceivedPublisher"), object: nil))
    }
}
