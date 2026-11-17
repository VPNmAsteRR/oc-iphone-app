import SwiftUI
import WebKit

/// Полноэкранный настоящий интерфейс OpenCode.
///
/// Пароль передаётся не через адрес и не через прокси, а нативным
/// обработчиком WKWebView: он отвечает на запрос авторизации сервера
/// заголовком Basic. Поэтому работают все запросы интерфейса —
/// загрузка сессий, поток событий, терминал, файлы.
struct WebView: UIViewRepresentable {
    let url: URL
    let username: String
    let password: String
    let reloadToken: Int
    let onStateChange: (WebState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(username: username, password: password, onStateChange: onStateChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.websiteDataStore = .default()

        // Разрешаем всё для своего сервера: интерфейс использует потоки и запросы.
        let controller = WKUserContentController()

        // Тёмная тема и корректные отступы под вырез экрана.
        let css = """
        :root { color-scheme: dark; }
        html, body { background: #0e1014 !important; overscroll-behavior: none; }
        """
        let script = WKUserScript(source: """
        (function() {
            const s = document.createElement('style');
            s.textContent = `\(css.replacingOccurrences(of: "`", with: "\\`"))`;
            document.addEventListener('DOMContentLoaded', () => document.head.appendChild(s));
        })();
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        controller.addUserScript(script)

        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.keyboardDismissMode = .interactive
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.055, green: 0.063, blue: 0.078, alpha: 1)
        web.underPageBackgroundColor = web.backgroundColor
        web.scrollView.backgroundColor = web.backgroundColor

        context.coordinator.webView = web
        context.coordinator.load(url: url)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.username = username
        context.coordinator.password = password
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.load(url: url)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeAllUserScripts()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var username: String
        var password: String
        var lastReloadToken = 0
        let onStateChange: (WebState) -> Void
        weak var webView: WKWebView?
        private var authRetries = 0

        init(username: String, password: String, onStateChange: @escaping (WebState) -> Void) {
            self.username = username
            self.password = password
            self.onStateChange = onStateChange
        }

        func load(url: URL) {
            authRetries = 0
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 60
            webView?.load(request)
        }

        // MARK: Авторизация

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let space = challenge.protectionSpace

            if space.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
                space.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
                guard authRetries < 4 else {
                    completionHandler(.performDefaultHandling, nil)
                    return
                }
                authRetries += 1
                let credential = URLCredential(user: username, password: password,
                                               persistence: .forSession)
                completionHandler(.useCredential, credential)
                return
            }

            if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = space.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }

            completionHandler(.performDefaultHandling, nil)
        }

        // MARK: Состояние

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            authRetries = 0
            onStateChange(.ready)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // Отмена загрузки — не ошибка (например, редирект).
            if ns.code == NSURLErrorCancelled { return }
            onStateChange(.failed(ns.localizedDescription))
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let http = navigationResponse.response as? HTTPURLResponse,
               http.statusCode == 401 {
                onStateChange(.unauthorized)
            }
            decisionHandler(.allow)
        }

        // MARK: Диалоги интерфейса

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            present(title: nil, message: message, completionHandler: completionHandler)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in completionHandler(true) })
            topController()?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            topController()?.present(alert, animated: true)
        }

        private func present(title: String?, message: String, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in completionHandler() })
            topController()?.present(alert, animated: true)
        }

        private func topController() -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }
    }
}

enum WebState: Equatable {
    case loading
    case ready
    case unauthorized
    case failed(String)
}
