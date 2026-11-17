import UIKit
import WebKit
import StoreKit
import Capacitor
import FirebaseCore
import FirebaseMessaging

/* =====================================================================
   단톡방 iOS (2026-11-17) — 단골창구 iOS 에서 이름만 바꿔 가져왔습니다.
   dantok.kr 을 띄우는 껍데기입니다. 알림 · 애플 결제만 앱이 하고, 화면은 모두 웹입니다.
   ① 알림   : 애플 기기 번호 → Firebase 번호로 바꿔 화면에 넘깁니다(가림콜과 같은 서버 길 · dt.js pushSync).
   ② 결제   : 화면 AliasNative.storeBuy('dantok_room_1y') → 애플 상품 dantok_room_1y_nr → 서버 aliascall-google-verify
   화면(웹)과 주고받는 창구: window.webkit.messageHandlers.aliasIOS.postMessage({ act: 'storeBuy' | 'storeConsume' | 'storeFlush' | 'openSettings' })
   ===================================================================== */

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 🔴 Firebase 켜기 — 값은 빌드 때 GoogleService-Info.plist 에서 채워 넣습니다(ios_setup.py)
        let o = FirebaseOptions(googleAppID: "__GOOGLE_APP_ID__", gcmSenderID: "__GCM_SENDER_ID__")
        o.apiKey = "__API_KEY__"
        o.projectID = "__PROJECT_ID__"
        o.bundleID = "__BUNDLE_ID__"
        o.storageBucket = "__STORAGE_BUCKET__"
        FirebaseApp.configure(options: o)
        // 애플 결제 — 앱이 꺼진 사이 끝난 결제도 여기서 받습니다
        AliasStore.shared.start()
        // 🔧 2026-11-16 화면(웹)에 결제 창구(AliasNative) 붙이기 — 장면(Scene) 방식 앱은 applicationDidBecomeActive 가
        //    불리지 않을 수 있어서, 켜질 때 바로 붙이고(화면이 준비될 때까지 0.5초마다 다시 시도) 앱이 다시 앞으로 올 때마다 확인합니다.
        DantokWeb.shared.attachWeb()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            DantokWeb.shared.attachWeb()
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        DantokWeb.shared.attachWeb()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { token, error in
            if let error = error {
                NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
            } else if let token = token {
                NotificationCenter.default.post(name: .capacitorDidRegisterForRemoteNotifications, object: token)
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .capacitorDidFailToRegisterForRemoteNotifications, object: error)
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/* =====================================================================
   DantokWeb — 화면(웹)과 잇기: 안드로이드와 같은 이름의 창구(AliasNative)를 아이폰에도 엽니다
   ===================================================================== */
final class DantokWeb: NSObject, WKScriptMessageHandler {
    static let shared = DantokWeb()
    private weak var attachedWeb: WKWebView?

    func currentWebView() -> WKWebView? {
        for sc in UIApplication.shared.connectedScenes {
            guard let ws = sc as? UIWindowScene else { continue }
            for w in ws.windows {
                if let vc = w.rootViewController as? CAPBridgeViewController, let wv = vc.bridge?.webView { return wv }
            }
        }
        return nil
    }

    static let shimJS = #"""
    (function(){
      if (window.AliasNative) return;
      function post(m){ try { window.webkit.messageHandlers.aliasIOS.postMessage(m); } catch (e) {} }
      function account(){
        try {
          for (var i = 0; i < localStorage.length; i++) {
            var k = localStorage.key(i);
            if (/^sb-.*-auth-token$/.test(k)) {
              var v = JSON.parse(localStorage.getItem(k) || 'null');
              var u = v && (v.user || (v.currentSession && v.currentSession.user));
              if (u && u.id) return String(u.id);
            }
          }
        } catch (e) {}
        return '';
      }
      window.AliasNative = {
        isIOS: function(){ return true; },
        appKind: function(){ return 'dantok'; },
        storeBuy: function(sku){ post({ act: 'storeBuy', sku: String(sku || ''), account: account() }); },
        storeConsume: function(token){ post({ act: 'storeConsume', token: String(token || '') }); },
        storeFlush: function(){ post({ act: 'storeFlush' }); },
        storeRecover: function(){ post({ act: 'storeFlush' }); },
        openNotificationSettings: function(){ post({ act: 'openSettings' }); }
      };
    })();
    """#

    func attachWeb() {
        guard let wv = currentWebView() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.attachWeb() }
            return
        }
        if attachedWeb === wv { return }
        let ucc = wv.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: "aliasIOS")
        ucc.add(self, name: "aliasIOS")
        ucc.addUserScript(WKUserScript(source: "window.ALIAS_APP='dantok';" + DantokWeb.shimJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        attachedWeb = wv
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.alwaysBounceHorizontal = false
        runJS("window.ALIAS_APP='dantok';" + DantokWeb.shimJS)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let m = message.body as? [String: Any], let act = m["act"] as? String else { return }
        switch act {
        case "storeBuy": AliasStore.shared.buy(sku: (m["sku"] as? String) ?? "", account: (m["account"] as? String) ?? "")
        case "storeConsume": AliasStore.shared.consume(token: (m["token"] as? String) ?? "")
        case "storeFlush": AliasStore.shared.flush()
        case "openSettings":
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        default: break
        }
    }

    private func runJS(_ js: String) {
        DispatchQueue.main.async { self.currentWebView()?.evaluateJavaScript(js, completionHandler: nil) }
    }
}

/* =====================================================================
   AliasStore — 애플 결제 (가림 aliascall-ios 와 같은 코드 · 상품 번호 = 안드로이드 번호 + "_nr")
   ===================================================================== */
final class AliasStore {
    static let shared = AliasStore()
    private var updates: Task<Void, Never>?
    private var waiting: [String: Transaction] = [:]     // 'apple:<id>' → 아직 정리 안 한 거래 (메인에서만 만짐)
    private var outbox: [[String: Any]] = []             // 화면이 준비되기 전에 생긴 소식 (메인에서만 만짐)
    private var sending = false                          // 같은 소식을 두 번 보내지 않게

    func start() {
        if updates != nil { return }
        updates = Task.detached { [weak self] in
            for await r in Transaction.updates { await self?.handle(r) }
        }
    }

    func buy(sku: String, account: String) {
        if sku.isEmpty { toWeb("storeError", sku, "상품 번호가 없습니다"); return }
        Task {
            do {
                /* 🔴 애플 상품 번호 = 안드로이드 번호 + "_nr"(비갱신 구독). 다시 만든 것은 _nr2 · _nr3 … 큰 번호를 먼저 씁니다 */
                let ids = [sku + "_nr5", sku + "_nr4", sku + "_nr3", sku + "_nr2", sku + "_nr", sku]
                let found = try await Product.products(for: ids)
                guard let p = ids.compactMap({ id in found.first(where: { $0.id == id }) }).first else {
                    self.toWeb("storeError", sku, "상품을 찾지 못했습니다 (" + sku + ")")
                    return
                }
                var opts: Set<Product.PurchaseOption> = []
                if let u = UUID(uuidString: account) { opts.insert(.appAccountToken(u)) }
                let r = try await p.purchase(options: opts)
                switch r {
                case .success(let v): await self.handle(v)
                case .userCancelled: self.toWeb("storeCanceled", sku, "")
                case .pending: self.toWeb("storePending", sku, "")
                @unknown default: self.toWeb("storeError", sku, "결제가 끝나지 않았습니다")
                }
            } catch {
                self.toWeb("storeError", sku, "결제를 시작하지 못했습니다 (" + error.localizedDescription + ")")
            }
        }
    }

    private func handle(_ v: VerificationResult<Transaction>) async {
        guard case .verified(let t) = v else {
            toWeb("storeError", "", "애플이 확인하지 못한 결제입니다")
            return
        }
        if t.revocationDate != nil {           // 환불 · 취소된 것은 정리만
            await t.finish()
            return
        }
        let token = "apple:" + String(t.id)
        DispatchQueue.main.async {
            self.waiting[token] = t
            let plain = t.productID.replacingOccurrences(of: "_nr[0-9]*$", with: "", options: .regularExpression)
            self.toWeb("storePurchase", plain, token, String(t.originalID))
        }
    }

    /* 서버가 확인을 마쳤습니다 → 정리 */
    func consume(token: String) {
        DispatchQueue.main.async {
            if let t = self.waiting[token] {
                self.waiting[token] = nil
                Task { await t.finish() }
                return
            }
            Task {
                for await r in Transaction.unfinished {
                    if case .verified(let t) = r, "apple:" + String(t.id) == token { await t.finish() }
                }
            }
        }
    }

    /* 화면이 준비됐습니다 → 못 끝낸 결제를 다시 보냅니다 */
    func flush() {
        DispatchQueue.main.async { self.drain() }
        Task {
            for await r in Transaction.unfinished { await self.handle(r) }
        }
    }

    private func toWeb(_ kind: String, _ sku: String, _ a: String, _ b: String = "") {
        let ev: [String: Any] = ["kind": kind, "sku": sku, "a": a, "b": b, "code": 0]
        DispatchQueue.main.async {
            self.outbox.append(ev)
            self.drain()
        }
    }

    /* 화면(공용 파일)이 준비돼야 받을 수 있습니다. 준비 전이면 0.5초마다 다시. (메인에서만 부름) */
    private func drain(tries: Int = 40, retry: Bool = false) {
        if sending && !retry { return }
        guard let first = outbox.first else { sending = false; return }
        sending = true
        guard let wv = DantokWeb.shared.currentWebView(),
              let data = try? JSONSerialization.data(withJSONObject: first),
              let json = String(data: data, encoding: .utf8) else {
            if tries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.drain(tries: tries - 1, retry: true) }
            } else { sending = false }
            return
        }
        let js = "(function(){try{var ev=" + json + ";" +
            "if(typeof window.acStoreEvent==='function'){window.acStoreEvent(ev);return 'ok';}" +
            "if(window.AL&&typeof AL.onStoreEvent==='function'&&AL.sb){AL.onStoreEvent(ev);return 'ok';}" +
            "}catch(e){}return 'wait';})()"
        wv.evaluateJavaScript(js) { v, _ in
            DispatchQueue.main.async {
                if let r = v as? String, r == "ok" {
                    if !self.outbox.isEmpty { self.outbox.removeFirst() }
                    self.drain(retry: true)
                } else if tries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.drain(tries: tries - 1, retry: true) }
                } else {
                    self.sending = false
                }
            }
        }
    }
}
