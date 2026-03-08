import SwiftUI
import WebKit

#if os(macOS)
import AppKit



/// ContentBlockerManager'dan derlenen kuralları uygular.
/// YouTube domain'lerinde content blocker devre dışı bırakılır.
struct InAppWebView: View {
    let article: Article
    let url: URL
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var blockerManager = ContentBlockerManager.shared
    @State private var isReady = false
    
    var body: some View {
        Group {
            if isReady {
                InAppWKWebViewWrapper(url: url, ruleLists: blockerManager.ruleLists)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Reklam filtreleri yükleniyor...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            markAsRead()
            loadBlocker()
        }
        .onChange(of: article) {
            markAsRead()
        }
    }
    
    private func loadBlocker() {
        Task {
            await blockerManager.loadRules()
            isReady = true
        }
    }
    
    private func markAsRead() {
        if !article.isRead {
            article.isRead = true
            try? modelContext.save()
        }
    }
}

/// WKWebView'ı barındıran ve first responder sorununu çözen
/// özel NSView konteyner sınıfı.
class WebViewContainerView: NSView {
    let webView: WKWebView
    var currentRuleLists: [WKContentRuleList] = []
    var loadedURL: URL?
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return webView.becomeFirstResponder()
    }
    
    // İlk tıklamada WKWebView'a odaklan
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(webView)
    }
}

/// NSViewRepresentable wrapper — first responder destekli
/// YouTube domain'lerinde content blocker otomatik devre dışı bırakılır.
struct InAppWKWebViewWrapper: NSViewRepresentable {
    let url: URL
    let ruleLists: [WKContentRuleList]
    
    // MARK: - Coordinator (Navigation + Script Handler)
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var ruleLists: [WKContentRuleList]
        private var isYouTubePage = false
        
        init(ruleLists: [WKContentRuleList]) {
            self.ruleLists = ruleLists
            super.init()
        }
        
        // MARK: WKScriptMessageHandler
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "adBlockerObserver", let body = message.body as? [String: Any], let count = body["blockedCount"] as? Int {
                DispatchQueue.main.async {
                    let currentCount = UserDefaults.standard.integer(forKey: "totalAdsBlocked")
                    UserDefaults.standard.set(currentCount + count, forKey: "totalAdsBlocked")
                }
            }
        }
        
        // MARK: WKNavigationDelegate
        
        /// YouTube domain'lerinde content blocker kurallarını devre dışı bırak.
        /// Bu sayede video seek, thumbnail yükleme ve Google giriş sorunları çözülür.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let requestURL = navigationAction.request.url {
                let isYouTube = ContentBlockerManager.isYouTubeRelatedURL(requestURL)
                
                if isYouTube && !isYouTubePage {
                    // YouTube sayfasına girildi — content blocker'ları kaldır
                    isYouTubePage = true
                    webView.configuration.userContentController.removeAllContentRuleLists()
                    print("YouTube algılandı — content blocker kuralları devre dışı bırakıldı: \(requestURL.host ?? "")")
                } else if !isYouTube && isYouTubePage {
                    // YouTube'dan çıkıldı — content blocker'ları geri ekle
                    isYouTubePage = false
                    for ruleList in ruleLists {
                        webView.configuration.userContentController.add(ruleList)
                    }
                    print("YouTube dışına çıkıldı — content blocker kuralları geri yüklendi.")
                }
            }
            return .allow
        }
        
        /// Sayfa yüklendikten sonra YouTube kozmetik reklam gizleme script'i inject et
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let currentURL = webView.url,
                  ContentBlockerManager.isYouTubeRelatedURL(currentURL) else { return }
            
            let youtubeAdHideScript = """
            (function() {
                'use strict';
                const hideYTAds = () => {
                    // Masthead banner reklamı
                    document.querySelectorAll('#masthead-ad, #player-ads, .ytp-ad-module, .ytp-ad-overlay-container, .ytp-ad-text-overlay, .ad-container, ytd-promoted-sparkles-web-renderer, ytd-display-ad-renderer, ytd-companion-slot-renderer, ytd-action-companion-ad-renderer, ytd-in-feed-ad-layout-renderer, ytd-ad-slot-renderer, #player-overlay\\\\:8, .ytd-banner-promo-renderer, tp-yt-paper-dialog.ytd-popup-container').forEach(el => {
                        if (el.style.display !== 'none') {
                            el.style.setProperty('display', 'none', 'important');
                        }
                    });
                    // Reklam overlay kapatma butonu varsa tıkla
                    document.querySelectorAll('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, button[class*="skip"]').forEach(btn => {
                        try { btn.click(); } catch(e) {}
                    });
                };
                hideYTAds();
                const obs = new MutationObserver(() => hideYTAds());
                obs.observe(document.body, { childList: true, subtree: true });
                // Her 2 saniyede bir de kontrol et (bazı reklamlar geç inject olur)
                setInterval(hideYTAds, 2000);
            })();
            """
            
            webView.evaluateJavaScript(youtubeAdHideScript) { _, error in
                if let error = error {
                    print("YouTube kozmetik script hatası: \(error.localizedDescription)")
                } else {
                    print("YouTube kozmetik reklam gizleme aktif.")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(ruleLists: ruleLists)
    }
    
    func makeNSView(context: Context) -> WebViewContainerView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences

        // YouTube ve diğer medya oynatıcılar için:
        // - Otomatik oynatma izni (kullanıcı etkileşimi gerekmeksizin)
        // - Inline oynatma (pencere dışına çıkmadan)
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        
        // --- Kalıcı Cookie Store ---
        // YouTube giriş bilgilerini ve oturum cookie'lerini korumak için
        // default (kalıcı) data store kullan
        let persistYouTube = UserDefaults.standard.bool(forKey: "persistYouTubeSession")
        if persistYouTube || ContentBlockerManager.isYouTubeRelatedURL(url) {
            configuration.websiteDataStore = WKWebsiteDataStore.default()
        }
        
        // Setup message handler
        configuration.userContentController.add(context.coordinator, name: "adBlockerObserver")
        
        // --- Kozmetik Filtreleme Scripti (Boş Reklam Alanlarını Gizleme) ---
        let cosmeticScriptSource = """
        const cosmeticFilter = () => {
            let newlyBlockedCount = 0;
            const processElement = (el) => {
                if (el.style.display !== 'none') {
                    el.style.setProperty('display', 'none', 'important');
                    newlyBlockedCount++;
                }
            };

            const selectors = [
                '.ad-banner', '.ad-container', '.ad-slot', '.advertisement',
                '[id^="google_ads_"]', 'ins.adsbygoogle[data-ad-status="unfilled"]'
            ];
            selectors.forEach(sel => {
                try {
                    document.querySelectorAll(sel).forEach(el => processElement(el));
                } catch(e) {}
            });

            document.querySelectorAll('iframe, div').forEach(el => {
                if (el.tagName.toLowerCase() === 'iframe') {
                    if (!el.src || el.src === 'about:blank' || el.src === '') {
                        processElement(el);
                    }
                } else {
                    if ((el.id && el.id.includes('ad-')) || (el.className && typeof el.className === 'string' && el.className.includes('ad-'))) {
                        if (el.innerHTML.trim() === '') {
                            processElement(el);
                        }
                    }
                }
            });
            
            if (newlyBlockedCount > 0 && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.adBlockerObserver) {
                window.webkit.messageHandlers.adBlockerObserver.postMessage({ "blockedCount": newlyBlockedCount });
            }
        };
        cosmeticFilter();
        const observer = new MutationObserver(() => cosmeticFilter());
        observer.observe(document.body, { childList: true, subtree: true });
        """
        
        let userScript = WKUserScript(
            source: cosmeticScriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(userScript)
        // -----------------------------------
        
        // YouTube domain'inde content blocker ekleme
        let isYouTube = ContentBlockerManager.isYouTubeRelatedURL(url)
        if !isYouTube {
            for ruleList in ruleLists {
                configuration.userContentController.add(ruleList)
            }
        } else {
            print("YouTube URL algılandı — content blocker başlangıçta uygulanmadı.")
        }
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator

        // Safari UA — YouTube'un tam özellikli player'ını sunması için
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        webView.load(URLRequest(url: url))
        
        let container = WebViewContainerView(webView: webView)
        container.currentRuleLists = ruleLists
        container.loadedURL = url
        
        // İlk yükleme sonrası focus ver
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            container.window?.makeFirstResponder(webView)
        }
        
        return container
    }
    
    func updateNSView(_ nsView: WebViewContainerView, context: Context) {
        // Coordinator'daki rule listesini güncelle
        context.coordinator.ruleLists = ruleLists
        
        // Update URL if changed
        if nsView.loadedURL != url {
            nsView.loadedURL = url
            nsView.webView.load(URLRequest(url: url))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nsView.window?.makeFirstResponder(nsView.webView)
            }
        }
        
        // Update rule lists if changed (sadece YouTube dışı sayfalarda)
        if nsView.currentRuleLists != ruleLists {
            let currentURL = nsView.webView.url ?? url
            let isYouTube = ContentBlockerManager.isYouTubeRelatedURL(currentURL)
            
            if !isYouTube {
                nsView.webView.configuration.userContentController.removeAllContentRuleLists()
                for ruleList in ruleLists {
                    nsView.webView.configuration.userContentController.add(ruleList)
                }
                
                // Reklam engelleme kuralları eklendiğinde yenile
                if !nsView.webView.isLoading && nsView.webView.url != nil {
                    nsView.webView.reload()
                    print("ContentBlocker: Yeni kural listesi uygulandı ve sayfa yenilendi.")
                }
            }
            nsView.currentRuleLists = ruleLists
        }
    }
}

#endif
