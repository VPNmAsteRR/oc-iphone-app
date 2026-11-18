import SwiftUI
import UIKit
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
    let zoom: Double
    let reloadToken: Int
    let onStateChange: (WebState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(username: username, password: password,
                    onStateChange: onStateChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        config.websiteDataStore = .default()
        // Полноэкранные модальные окна и всплывающие окна интерфейса.
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let controller = WKUserContentController()

        // Настоящее оформление OpenCode в духе Gemini: свои переменные темы,
        // чёрный фон, синее свечение, стеклянные панели, аккуратные нажатия.
        // Текст стилей лежит в Sources/ShellCSS.swift (собирается из Resources/shell.css).
        let css = ShellCSS.styles

        let styleScript = WKUserScript(source: """
        (function() {
          var CSS = `__OC_CSS__`;

          // Стили OpenCode подключаются ссылками в <head> и загружаются
          // ПОСЛЕ наших вставок. Поэтому свою таблицу держим последней
          // в документе: при равной специфичности побеждает то, что ниже.
          function apply() {
            var style = document.getElementById('__oc_shell_style');
            if (!style) {
              style = document.createElement('style');
              style.id = '__oc_shell_style';
            }
            if (style.textContent !== CSS) {
              style.textContent = CSS;
            }

            // Держим таблицу в <body>, но переставляем только если её
            // реально обогнали чужие стили. Иначе каждый тост или окно
            // заставляли бы браузер заново разбирать всю таблицу.
            var body = document.body;
            if (!body) {
              if (style.parentNode !== document.documentElement) {
                document.documentElement.appendChild(style);
              }
              return;
            }
            if (style.parentNode !== body) {
              body.appendChild(style);
              return;
            }
            var later = false;
            var nodes = body.children;
            for (var i = nodes.length - 1; i >= 0; i--) {
              var node = nodes[i];
              if (node === style) break;
              if (node.tagName === 'STYLE' || node.tagName === 'LINK') { later = true; break; }
            }
            if (later) body.appendChild(style);
          }

          apply();
          document.addEventListener('DOMContentLoaded', apply);
          window.addEventListener('load', apply);

          // Новые стили, шрифты и подгружаемые куски интерфейса появляются
          // в процессе работы — возвращаем свою таблицу в конец.
          var pending = false;
          function schedule() {
            if (pending) return;
            pending = true;
            setTimeout(function() {
              pending = false;
              apply();
            }, 120);
          }

          try {
            new MutationObserver(schedule).observe(document.documentElement, {
              childList: true, subtree: true
            });
          } catch (e) {}

          // Страховка на первые секунды: интерфейс собирается постепенно.
          [80, 300, 800, 1600, 3000].forEach(function (ms) {
            setTimeout(apply, ms);
          });
        })();
        """.replacingOccurrences(of: "__OC_CSS__", with: css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")),
            injectionTime: .atDocumentStart, forMainFrameOnly: true)
        controller.addUserScript(styleScript)

        // Разметка ключевых элементов интерфейса стабильными классами
        // и поведение при появлении клавиатуры.
        let markScript = WKUserScript(source: ThemeMark.script,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)
        controller.addUserScript(markScript)

        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.keyboardDismissMode = .interactive
        web.allowsLinkPreview = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.underPageBackgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.bounces = true
        web.pageZoom = CGFloat(zoom)

        // Убираем серую полосу с «‹ › Готово» над клавиатурой:
        // она перекрывает поле ввода и мешает.
        web.inputAssistantItem.leadingBarButtonGroups = []
        web.inputAssistantItem.trailingBarButtonGroups = []

        context.coordinator.webView = web
        context.coordinator.installPullToRefresh(on: web)
        context.coordinator.load(url: url)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.username = username
        context.coordinator.password = password

        if abs(web.pageZoom - CGFloat(zoom)) > 0.001 {
            web.pageZoom = CGFloat(zoom)
        }

        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.load(url: url)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeAllUserScripts()
        coordinator.removePullToRefresh(from: web)
        coordinator.disarmWatchdog()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var username: String
        var password: String
        var lastReloadToken = 0
        var onStateChange: (WebState) -> Void
        weak var webView: WKWebView?
        private var authRetries = 0
        private var refreshControl: UIRefreshControl?
        private var watchdog: Task<Void, Never>?

        init(username: String, password: String,
             onStateChange: @escaping (WebState) -> Void) {
            self.username = username
            self.password = password
            self.onStateChange = onStateChange
        }

        /// Если страница начала грузиться и зависла — сообщаем об ошибке,
        /// а не оставляем человека смотреть на пустой экран.
        func armWatchdog() {
            watchdog?.cancel()
            watchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, let self, let web = self.webView else { return }
                if web.isLoading {
                    self.refreshControl?.endRefreshing()
                    self.onStateChange(.failed("Сервер не ответил вовремя"))
                }
            }
        }

        func disarmWatchdog() {
            watchdog?.cancel()
            watchdog = nil
        }

        func load(url: URL) {
            authRetries = 0
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            request.timeoutInterval = 30
            armWatchdog()
            onStateChange(.loading)
            webView?.load(request)
        }

        // MARK: Обновление жестом сверху вниз

        func installPullToRefresh(on web: WKWebView) {
            let control = UIRefreshControl()
            control.tintColor = UIColor(red: 0.486, green: 0.361, blue: 1.0, alpha: 1)
            control.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            web.scrollView.refreshControl = control
            refreshControl = control
        }

        func removePullToRefresh(from web: WKWebView) {
            web.scrollView.refreshControl = nil
            refreshControl = nil
        }

        @objc private func handleRefresh() {
            // Обновляем страницу целиком: так гарантированно подтягиваются
            // новые сессии и сообщения, написанные с другого устройства.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            armWatchdog()
            webView?.reload()
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
            armWatchdog()
            onStateChange(.loading)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            authRetries = 0
            disarmWatchdog()
            refreshControl?.endRefreshing()
            onStateChange(.ready)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            disarmWatchdog()
            refreshControl?.endRefreshing()
            onStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled {
                // Отмена — часть редиректа, сторож не снимаем: загрузка ещё идёт.
                return
            }
            disarmWatchdog()
            refreshControl?.endRefreshing()
            onStateChange(.failed(error.localizedDescription))
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

        /// Ссылки «в новом окне» открываем в том же экране, чтобы не терять интерфейс.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
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
