import Foundation
import UIKit

enum MapNavigationProvider: String, CaseIterable, Identifiable {
    case appleMaps
    case amap
    case baidu
    case tencent
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMaps:
            return "Apple 地图"
        case .amap:
            return "高德地图"
        case .baidu:
            return "百度地图"
        case .tencent:
            return "腾讯地图"
        case .google:
            return "Google 地图"
        }
    }

    var probeURL: URL {
        switch self {
        case .appleMaps:
            return URL(string: "maps://")!
        case .amap:
            return URL(string: "iosamap://")!
        case .baidu:
            return URL(string: "baidumap://")!
        case .tencent:
            return URL(string: "qqmap://")!
        case .google:
            return URL(string: "comgooglemaps://")!
        }
    }
}

struct MapNavigationOption: Identifiable {
    let provider: MapNavigationProvider
    let url: URL

    var id: String { provider.id }
    var displayName: String { provider.displayName }
}

@MainActor
struct MapNavigationService {
    static let appStoreSearchURL = URL(
        string: "itms-apps://itunes.apple.com/search?term=%E5%9C%B0%E5%9B%BE%E5%AF%BC%E8%88%AA&media=software"
    )!

    static let live = MapNavigationService { url in
        UIApplication.shared.canOpenURL(url)
    }

    private let canOpenURL: (URL) -> Bool

    init(canOpenURL: @escaping (URL) -> Bool) {
        self.canOpenURL = canOpenURL
    }

    func availableOptions(for rawAddress: String) -> [MapNavigationOption] {
        let address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            return []
        }

        return MapNavigationProvider.allCases.compactMap { provider in
            guard canOpenURL(provider.probeURL), let url = navigationURL(for: provider, address: address) else {
                return nil
            }
            return MapNavigationOption(provider: provider, url: url)
        }
    }

    func navigationURL(for provider: MapNavigationProvider, address: String) -> URL? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return nil
        }

        switch provider {
        case .appleMaps:
            return makeURL(
                scheme: "maps",
                host: "",
                path: "",
                queryItems: [
                    URLQueryItem(name: "daddr", value: trimmedAddress),
                    URLQueryItem(name: "dirflg", value: "d")
                ]
            )
        case .amap:
            return makeURL(
                scheme: "iosamap",
                host: "path",
                path: "",
                queryItems: [
                    URLQueryItem(name: "sourceApplication", value: "一句话提醒"),
                    URLQueryItem(name: "dname", value: trimmedAddress),
                    URLQueryItem(name: "dev", value: "0"),
                    URLQueryItem(name: "t", value: "0")
                ]
            )
        case .baidu:
            return makeURL(
                scheme: "baidumap",
                host: "map",
                path: "/direction",
                queryItems: [
                    URLQueryItem(name: "destination", value: trimmedAddress),
                    URLQueryItem(name: "mode", value: "driving"),
                    URLQueryItem(name: "coord_type", value: "gcj02"),
                    URLQueryItem(name: "src", value: "ios.yijuhua.tixing")
                ]
            )
        case .tencent:
            return makeURL(
                scheme: "qqmap",
                host: "map",
                path: "/routeplan",
                queryItems: [
                    URLQueryItem(name: "type", value: "drive"),
                    URLQueryItem(name: "to", value: trimmedAddress),
                    URLQueryItem(name: "referer", value: "YijuhuaTixing")
                ]
            )
        case .google:
            return makeURL(
                scheme: "comgooglemaps",
                host: "",
                path: "",
                queryItems: [
                    URLQueryItem(name: "daddr", value: trimmedAddress),
                    URLQueryItem(name: "directionsmode", value: "driving")
                ]
            )
        }
    }

    private func makeURL(
        scheme: String,
        host: String?,
        path: String,
        queryItems: [URLQueryItem]
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}
