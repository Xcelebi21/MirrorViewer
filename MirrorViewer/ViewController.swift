import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    var spinner: UIActivityIndicatorView!
    var errorOverlay: UIView!

    // TrollVNC serves static noVNC files over HTTP, but the RFB/WebSocket
    // endpoint lives on the VNC port itself. So the web port and the socket
    // port differ, and `path` must be empty (noVNC defaults to "websockify",
    // which TrollVNC 404s).

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        buildErrorOverlay()

        if let saved = UserDefaults.standard.string(forKey: "mirrorURL"),
           let url = URL(string: saved) {
            load(url)
        } else {
            promptForURL()
        }
    }

    // No URL saved / user cancelled -> load the default URL so the screen is never black.
    func loadDefault() {
        let text = "192.168.50.188:8081"
        if let url = buildURL(from: text) {
            UserDefaults.standard.set(url.absoluteString, forKey: "mirrorURL")
            load(url)
        }
    }

    func load(_ url: URL) {
        errorOverlay.isHidden = true
        spinner.startAnimating()
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
    }

    func promptForURL(defaultURL: String? = nil) {
        let defaultText = defaultURL ?? "192.168.50.188:8081"
        let alert = UIAlertController(title: "Mirror URL",
                                       message: "Enter the other phone's address. Use its web port (8081) â€” the VNC port is detected automatically.",
                                       preferredStyle: .alert)
        alert.addTextField {
            $0.text = defaultText
            $0.placeholder = defaultText
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .none
            $0.keyboardType = .URL
        }
        alert.addTextField {
            $0.placeholder = "Password (optional)"
            $0.isSecureTextEntry = true
            $0.autocorrectionType = .no
            $0.autocapitalizationType = .none
            if let saved = UserDefaults.standard.string(forKey: "mirrorPassword") {
                $0.text = saved
            }
        }
        alert.addAction(UIAlertAction(title: "Connect", style: .default) { [weak self] _ in
            let pw = alert.textFields?.last?.text ?? ""
            UserDefaults.standard.set(pw, forKey: "mirrorPassword")
            guard let t = alert.textFields?.first?.text else {
                self?.loadDefault(); return
            }
            self?.acceptURL(t)
        })
        alert.addAction(UIAlertAction(title: "Cancel (use default)", style: .cancel) { [weak self] _ in
            self?.loadDefault()
        })
        present(alert, animated: true)
    }

    /// Accepts "ip", "ip:port", "host:port", or a full URL and returns a noVNC
    /// URL wired to TrollVNC's real WebSocket endpoint.
    func buildURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }

        // Strip any path/query the user pasted; we rebuild them.
        guard var comps = URLComponents(string: text) else { return nil }
        guard let host = comps.host, !host.isEmpty else { return nil }

        let webPort = comps.port ?? 8081
        // TrollVNC's RFB/WebSocket listener defaults to 5901. If the user gave
        // the web port only, assume the default VNC port.
        let sockPort = (webPort == 8081 || webPort == 5801) ? 5901 : webPort

        var q: [URLQueryItem] = [
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(sockPort)),
            URLQueryItem(name: "path", value: ""),
            URLQueryItem(name: "autoconnect", value: "true"),
            URLQueryItem(name: "resize", value: "scale"),
        ]
        if let saved = UserDefaults.standard.string(forKey: "mirrorPassword"), !saved.isEmpty {
            q.append(URLQueryItem(name: "password", value: saved))
        }
        comps.path = "/novnc/vnc.html"
        comps.queryItems = q
        return comps.url
    }

    func acceptURL(_ raw: String) {
        if let url = buildURL(from: raw) {
            UserDefaults.standard.set(url.absoluteString, forKey: "mirrorURL")
            load(url)
        } else {
            promptForURL()
        }
    }

    func buildErrorOverlay() {
        errorOverlay = UIView()
        errorOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        errorOverlay.isHidden = true
        errorOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorOverlay)

        let label = UILabel()
        label.text = "Can't reach the mirror.\nCheck the IP, Tailscale, and TrollVNC."
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let retry = UIButton(type: .system)
        retry.setTitle("Retry", for: .normal)
        retry.titleLabel?.font = .boldSystemFont(ofSize: 18)
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retry.translatesAutoresizingMaskIntoConstraints = false

        let edit = UIButton(type: .system)
        edit.setTitle("Change URL", for: .normal)
        edit.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        edit.translatesAutoresizingMaskIntoConstraints = false

        errorOverlay.addSubview(label)
        errorOverlay.addSubview(retry)
        errorOverlay.addSubview(edit)

        NSLayoutConstraint.activate([
            errorOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            errorOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.centerXAnchor.constraint(equalTo: errorOverlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: errorOverlay.centerYAnchor, constant: -40),
            label.widthAnchor.constraint(equalTo: errorOverlay.widthAnchor, multiplier: 0.8),
            retry.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
            retry.centerXAnchor.constraint(equalTo: errorOverlay.centerXAnchor),
            edit.topAnchor.constraint(equalTo: retry.bottomAnchor, constant: 12),
            edit.centerXAnchor.constraint(equalTo: errorOverlay.centerXAnchor),
        ])
    }

    @objc func retryTapped() {
        if let saved = UserDefaults.standard.string(forKey: "mirrorURL"), let url = URL(string: saved) {
            load(url)
        } else { loadDefault() }
    }

    @objc func editTapped() { promptForURL() }

    // Force true full-screen (no status bar / home-indicator chrome).
    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { spinner.stopAnimating() }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating(); errorOverlay.isHidden = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating(); errorOverlay.isHidden = false
    }
}
