import Foundation

struct URLMetadata {
    let title: String?
    let description: String?
    let faviconData: Data?
    let imageData: Data?
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
                metadata = URLMetadata(title: url.lastPathComponent, description: nil, faviconData: data, imageData: data)
            } else if contentType.contains("text/html") || contentType.contains("application/xhtml+xml") {
                let encoding = response.textEncodingName.flatMap { String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding($0 as CFString))) } ?? .utf8
                guard let html = String(data: data, encoding: encoding) else {
                    return nil
                }

                let title = extractTitle(from: html)
                let description = extractDescription(from: html)
                let faviconURL = extractFaviconURL(from: html, baseURL: url)
                let imageURL = extractPreviewImageURL(from: html, baseURL: url)
                
                var faviconData: Data? = nil
                if let faviconURL {
                    faviconData = await fetchAssetData(from: faviconURL, maxBytes: 1_000_000)
                }
                
                // Fallback for favicon if not found or failed
                if faviconData == nil, let host = url.host, let fallback = URL(string: "\(url.scheme ?? "https")://\(host)/favicon.ico") {
                    faviconData = await fetchAssetData(from: fallback, maxBytes: 1_000_000)
                }

                var imageData: Data? = nil
                if let imageURL {
                    imageData = await fetchAssetData(from: imageURL, maxBytes: 5_000_000)
                }
                
                metadata = URLMetadata(title: title, description: description, faviconData: faviconData, imageData: imageData)
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
        if let title = metaContent(in: html, property: "og:title")
            ?? metaContent(in: html, name: "twitter:title")
        {
            return title
        }

        // Try standard title tag
        let pattern = "<title>(.*?)</title>"
        if let title = match(pattern: pattern, in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            return decodeHTMLEntities(title)
        }
        
        return nil
    }

    private func extractDescription(from html: String) -> String? {
        metaContent(in: html, property: "og:description")
            ?? metaContent(in: html, name: "twitter:description")
            ?? metaContent(in: html, name: "description")
    }

    private func extractFaviconURL(from html: String, baseURL: URL) -> URL? {
        for attrs in tags(named: "link", in: html) {
            guard let rel = attrs["rel"]?.lowercased(),
                  let href = attrs["href"],
                  rel.contains("icon")
            else {
                continue
            }
            return URL(string: decodeHTMLEntities(href), relativeTo: baseURL)?.absoluteURL
        }
        return nil
    }

    private func extractPreviewImageURL(from html: String, baseURL: URL) -> URL? {
        for key in ["og:image:secure_url", "og:image", "twitter:image"] {
            let value = key.hasPrefix("og:")
                ? metaContent(in: html, property: key)
                : metaContent(in: html, name: key)
            if let value, let url = URL(string: value, relativeTo: baseURL)?.absoluteURL {
                return url
            }
        }
        return nil
    }

    private func fetchAssetData(from url: URL, maxBytes: Int) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count <= maxBytes
            else {
                return nil
            }
            return data
        } catch {
            return nil
        }
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

    private func metaContent(in html: String, property: String? = nil, name: String? = nil) -> String? {
        for attrs in tags(named: "meta", in: html) {
            if let property,
               attrs["property"]?.caseInsensitiveCompare(property) == .orderedSame,
               let content = attrs["content"]
            {
                return decodeHTMLEntities(content)
            }
            if let name,
               attrs["name"]?.caseInsensitiveCompare(name) == .orderedSame,
               let content = attrs["content"]
            {
                return decodeHTMLEntities(content)
            }
        }

        if let property {
            return contentValue(in: html, near: "property=\"\(property)\"")
                ?? contentValue(in: html, near: "property='\(property)'")
        }
        if let name {
            return contentValue(in: html, near: "name=\"\(name)\"")
                ?? contentValue(in: html, near: "name='\(name)'")
        }
        return nil
    }

    private func contentValue(in html: String, near marker: String) -> String? {
        let lowerHTML = html.lowercased()
        let lowerMarker = marker.lowercased()
        let nsLower = lowerHTML as NSString
        let markerRange = nsLower.range(of: lowerMarker)
        guard markerRange.location != NSNotFound else { return nil }

        let prefixRange = NSRange(location: 0, length: markerRange.location)
        let tagStartRange = nsLower.range(of: "<meta", options: .backwards, range: prefixRange)
        guard tagStartRange.location != NSNotFound else { return nil }

        let suffixStart = markerRange.location + markerRange.length
        let suffixRange = NSRange(location: suffixStart, length: nsLower.length - suffixStart)
        let tagEndRange = nsLower.range(of: ">", options: [], range: suffixRange)
        guard tagEndRange.location != NSNotFound else {
            return nil
        }

        let tagRange = NSRange(location: tagStartRange.location, length: tagEndRange.location - tagStartRange.location + 1)
        guard let swiftRange = Range(tagRange, in: html) else { return nil }
        let tag = String(html[swiftRange])
        guard let contentRange = tag.range(of: "content", options: [.caseInsensitive]) else {
            return nil
        }

        var cursor = contentRange.upperBound
        while cursor < tag.endIndex, tag[cursor].isWhitespace { cursor = tag.index(after: cursor) }
        guard cursor < tag.endIndex, tag[cursor] == "=" else { return nil }
        cursor = tag.index(after: cursor)
        while cursor < tag.endIndex, tag[cursor].isWhitespace { cursor = tag.index(after: cursor) }
        guard cursor < tag.endIndex else { return nil }

        let quote = tag[cursor]
        if quote == "\"" || quote == "'" {
            let valueStart = tag.index(after: cursor)
            guard let valueEnd = tag[valueStart...].firstIndex(of: quote) else { return nil }
            return decodeHTMLEntities(String(tag[valueStart..<valueEnd]))
        }

        let valueStart = cursor
        var valueEnd = valueStart
        while valueEnd < tag.endIndex,
              !tag[valueEnd].isWhitespace,
              tag[valueEnd] != ">" {
            valueEnd = tag.index(after: valueEnd)
        }
        return decodeHTMLEntities(String(tag[valueStart..<valueEnd]))
    }

    private func tags(named tagName: String, in html: String) -> [[String: String]] {
        let pattern = "<\(tagName)\\b[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard let tagRange = Range(match.range, in: html) else { return nil }
            return attributes(in: String(html[tagRange]))
        }
    }

    private func attributes(in tag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [:]
        }

        var result: [String: String] = [:]
        let range = NSRange(tag.startIndex..., in: tag)
        for match in regex.matches(in: tag, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let key = String(tag[keyRange]).lowercased()
            for idx in 2...4 {
                let nsRange = match.range(at: idx)
                guard nsRange.location != NSNotFound,
                      let valueRange = Range(nsRange, in: tag)
                else {
                    continue
                }
                result[key] = String(tag[valueRange])
                break
            }
        }
        return result
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
