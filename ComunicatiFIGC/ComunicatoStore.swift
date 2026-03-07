import Foundation

struct Comunicato: Identifiable {
    var id: Int { number }
    let number: Int
    let title: String
    let date: String
    let viewPath: String
    let downloadPath: String

    var viewURL: URL? {
        URL(string: "https://www.figcvenetocalcio.it\(viewPath)")
    }

    var downloadURL: URL? {
        URL(string: "https://www.figcvenetocalcio.it\(downloadPath)")
    }
}

// MARK: - Fetcher (background-safe, no actor)

enum ComunicatoFetcher {
    static let pageURL = "https://www.figcvenetocalcio.it/pagina-resp.aspx?PId=27987"
    static let knownIDsKey = "knownComunicatoIDs"

    static func fetchAll() async throws -> [Comunicato] {
        guard let url = URL(string: pageURL) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }
        return parse(html: html)
    }

    static func checkForNew() async -> [Comunicato] {
        guard let comunicati = try? await fetchAll() else { return [] }
        return updateKnownAndGetNew(comunicati)
    }

    static func updateKnownAndGetNew(_ comunicati: [Comunicato]) -> [Comunicato] {
        let currentIDs = Set(comunicati.map(\.number))
        let stored = UserDefaults.standard.array(forKey: knownIDsKey) as? [Int] ?? []
        let knownIDs = Set(stored)
        let newIDs = currentIDs.subtracting(knownIDs)
        UserDefaults.standard.set(Array(currentIDs), forKey: knownIDsKey)
        return comunicati.filter { newIDs.contains($0.number) }
    }

    static func parse(html: String) -> [Comunicato] {
        var results: [Comunicato] = []
        var seen = Set<Int>()

        // Match download/view links for Com_XX.pdf
        let pattern = #"href="(/download\.ashx\?act=(download|vis)&(?:amp;)?file=([^"]*?Com_(\d+)\.pdf[^"]*))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))

        // Group matches by comunicato number
        var viewPaths: [Int: String] = [:]
        var downloadPaths: [Int: String] = [:]
        var positions: [Int: Int] = [:]

        for match in matches {
            guard match.numberOfRanges >= 5 else { continue }
            let fullPath = ns.substring(with: match.range(at: 1))
                .replacingOccurrences(of: "&amp;", with: "&")
            let action = ns.substring(with: match.range(at: 2))
            let numStr = ns.substring(with: match.range(at: 4))
            guard let num = Int(numStr) else { continue }

            if action == "vis" {
                viewPaths[num] = fullPath
            } else {
                downloadPaths[num] = fullPath
            }
            if positions[num] == nil {
                positions[num] = match.range.location
            }
        }

        let allNumbers = Set(viewPaths.keys).union(downloadPaths.keys)
        for num in allNumbers {
            guard !seen.contains(num) else { continue }
            seen.insert(num)

            let vp = viewPaths[num] ?? downloadPaths[num] ?? ""
            let dp = downloadPaths[num] ?? viewPaths[num] ?? ""
            let pos = positions[num] ?? 0

            results.append(Comunicato(
                number: num,
                title: "Comunicato \(num)",
                date: findDate(near: pos, in: ns),
                viewPath: vp,
                downloadPath: dp
            ))
        }

        return results.sorted { $0.number > $1.number }
    }

    private static func findDate(near pos: Int, in html: NSString) -> String {
        let start = max(0, pos - 500)
        let chunk = html.substring(with: NSRange(location: start, length: pos - start))
        let datePattern = #"(\d{2}/\d{2}/\d{2})"#
        guard let re = try? NSRegularExpression(pattern: datePattern) else { return "" }
        let ms = re.matches(in: chunk, range: NSRange(location: 0, length: chunk.count))
        guard let last = ms.last else { return "" }
        return (chunk as NSString).substring(with: last.range(at: 1))
    }
}

// MARK: - Store (UI, MainActor)

@MainActor
class ComunicatoStore: ObservableObject {
    @Published var comunicati: [Comunicato] = []
    @Published var isLoading = false
    @Published var error: String?

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            comunicati = try await ComunicatoFetcher.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkForNew() async -> [Comunicato] {
        await refresh()
        return ComunicatoFetcher.updateKnownAndGetNew(comunicati)
    }
}
