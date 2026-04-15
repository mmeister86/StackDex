import Combine
import Foundation
import Photos
import PhotosUI
#if canImport(UIKit)
import UIKit

@MainActor
final class RecentPhotoLibraryService: NSObject, ObservableObject {
    struct Item: Identifiable, Equatable {
        let id: String
        let thumbnail: UIImage
    }

    @Published private(set) var authorizationStatus: PHAuthorizationStatus
    @Published private(set) var items: [Item] = []

    var latestItem: Item? {
        items.first
    }

    private let imageManager = PHCachingImageManager()

    override init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAccessIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            authorizationStatus = current
        }
        return authorizationStatus
    }

    func loadRecent(limit: Int = 12) {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            items = []
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = max(1, limit)
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)

        let targetSize = CGSize(width: 120, height: 120)
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.resizeMode = .fast
        requestOptions.isSynchronous = true

        var resolvedItems: [Item] = []
        fetchResult.enumerateObjects { [weak self] asset, _, _ in
            guard let self else { return }
            self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                guard let image else { return }
                resolvedItems.append(Item(id: asset.localIdentifier, thumbnail: image))
            }
        }

        items = resolvedItems
    }

    func loadFullImage(for item: Item) async -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
        guard let asset = result.firstObject else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, orientation, _ in
                guard let data,
                      let image = ScanImagePreprocessor.image(from: data, orientation: orientation) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    func presentLimitedLibraryPicker() {
        guard let rootViewController = UIApplication.shared.activeKeyWindow?.rootViewController else {
            return
        }

        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootViewController)
    }
}

private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
#endif
