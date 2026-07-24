import SwiftUI
import SharedLogic
import PhotosUI

// MARK: - CoffeeEditorView 写真操作

extension CoffeeEditorView {

    /// PhotosPicker 選択後の処理。Data 取得 → JPEG 変換 → Photo_ 生成 → VM に通知。
    func handlePickerSelection(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                continue
            }

            let photoId = UUID().uuidString.lowercased()
            let fileName = "\(photoId).jpg"
            let localPath = "photos/\(fileName)"

            let widthPx = Int32(uiImage.size.width * uiImage.scale)
            let heightPx = Int32(uiImage.size.height * uiImage.scale)

            let epochMillis = Int64(Date().timeIntervalSince1970 * 1000)
            let createdAt = Kotlinx_datetimeInstant.Companion.shared.fromEpochMilliseconds(
                epochMilliseconds: epochMillis
            )

            let photo = Photo_(
                id: photoId,
                fileName: fileName,
                localPath: localPath,
                remoteUrl: nil,
                width: KotlinInt(value: widthPx),
                height: KotlinInt(value: heightPx),
                createdAt: createdAt
            )

            pendingImageData[photoId] = jpegData
            viewModel.onPhotoUpserted(item: photo)
        }
        selectedPickerItems = []
    }

    /// × ボタン押下時の写真削除処理。
    func handlePhotoDelete(photo: Photo_) {
        if pendingImageData.removeValue(forKey: photo.id) != nil {
            // 新規追加分: メモリから消すだけ。Documents にはまだ書かれていない
        } else {
            // 既存写真: 保存成功後に物理削除するため fileName を記録
            if let fileName = photo.fileName {
                removedFileNames.insert(fileName)
            }
        }
        viewModel.onPhotoRemoved(id: photo.id)
    }

    /// 保存ボタン押下時の処理。
    /// pendingImageData を Documents に書き出してから VM の onSaveTapped を呼ぶ。
    func saveWithPhotoFlush() async {
        let currentPhotos = viewModel.draft.photos
        var flushedFileNames: [String] = []
        do {
            for photo in currentPhotos {
                guard let data = pendingImageData[photo.id],
                      let fileName = photo.fileName else { continue }
                try PhotoFileStore.save(data: data, fileName: fileName)
                flushedFileNames.append(fileName)
            }
        } catch {
            // 書き出し失敗: 既に書いた分を rollback してエラー表示
            for fileName in flushedFileNames {
                try? PhotoFileStore.delete(fileName: fileName)
            }
            photoSaveError = error.localizedDescription
            return
        }

        // 全ファイル書き出し成功後に保存
        viewModel.onSaveTapped()
    }
}
