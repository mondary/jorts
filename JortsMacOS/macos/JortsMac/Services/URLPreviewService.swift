import Foundation

struct URLMetadata {
    let title: String?
    let faviconData: Data?
}

final class URLPreviewService {
    static let shared = URLPreviewService()
    private let session: URLSession
    private var cache: [URL: URLMetadata] = [:]
    private var ongoingTasks: [URL: Task<URLMetadata?, Never>] = [:]
    private let lock = NSLock()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchMetadata(for url: URL) async -> URLMetadata? {
        lock.lock()
        if let cached = cache[url] {
            lock.unlock()
            return cached
        }
        if let ongoing = ongoingTasks[url] {
            lock.unlock()
            return await ongoing.value
        }
        
        let task = Task {
            await performFetch(for: url)
        }
        ongoingTasks[url] = task
        lock.unlock()
        
        let result = await task.value
        
        lock.lock()
        ongoingTasks.removeValue(forKey: url)
        lock.unlock()
        
        return result
    }

    private func performFetch(for url: URL) async -> URLMetadata? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,image/*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            
            let metadata: URLMetadata
            if contentType.contains("image/") {
                metadata = URLMetadata(title: url.lastPathComponent, faviconData: data)
            } else if contentType.contains("text/html") || contentType.contains("application/xhtml+xml") {
                let encoding = response.textEncodingName.flatMap { String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding($0 as CFString))) } ?? .utf8
                guard let html = String(data: data, encoding: encoding) else {
                    return nil
                }

                let title = extractTitle(from: html)
                let faviconURL = extractFaviconURL(from: html, baseURL: url)
                
                var faviconData: Data? = nil
                if let faviconURL {
                    faviconData = try? await session.data(from: faviconURL).0
                }
                
                // Fallback for favicon if not found or failed
                if faviconData == nil, let host = url.host, let fallback = URL(string: "\(url.scheme ?? "https")://\(host)/favicon.ico") {
                    faviconData = try? await session.data(from: fallback).0
                }
                
                metadata = URLMetadata(title: title, faviconData: faviconData)
            } else {
                return nil
            }

            lock.lock()
            cache[url] = metadata
            lock.unlock()
            
            return metadata
        } catch {
            return nil
        }
    }

    private func extractTitle(from html: String) -> String? {
        // Try Open Graph title first
        let ogPatterns = [
            "<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:title[\"']"
        ]
        
        for pattern in ogPatterns {
            if let title = match(pattern: pattern, in: html) {
                return decodeHTMLEntities(title)
            }
        }

        // Try standard title tag
        let pattern = "<title>(.*?)</title>"
        if let title = match(pattern: pattern, in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            return decodeHTMLEntities(title)
        }
        
        return nil
    }

    private func extractFaviconURL(from html: String, baseURL: URL) -> URL? {
        let patterns = [
            "<link[^>]+rel=[\"'](?:shortcut )?icon[\"'][^>]+href=[\"']([^\"']+)[\"']",
            "<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"'](?:shortcut )?icon[\"']",
            "<link[^>]+rel=[\"']icon[\"'][^>]+href=[\"']([^\"']+)[\"']",
            "<link[^>]+rel=[\"']apple-touch-icon[\"'][^>]+href=[\"']([^\"']+)[\"']",
            "<meta[^>]+property=[\"']og:image[\"'][^>]+content=[\"']([^\"']+)[\"']"
        ]

        for pattern in patterns {
            if let href = match(pattern: pattern, in: html) {
                return URL(string: href, relativeTo: baseURL)
            }
        }
        return nil
    }

    private func match(pattern: String, in html: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, range: range),
           let matchRange = Range(match.range(at: 1), in: html) {
            return String(html[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func decodeHTMLEntities(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

