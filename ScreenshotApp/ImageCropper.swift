import AppKit

enum ImageCropper {
    static func crop(_ image: NSImage, to selection: CGRect, displayedIn displaySize: CGSize) -> NSImage? {
        guard displaySize.width > 0, displaySize.height > 0,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let displayRect = CGRect(origin: .zero, size: displaySize)
        let clampedSelection = selection.intersection(displayRect)
        guard clampedSelection.width >= 1, clampedSelection.height >= 1 else { return nil }

        let scaleX = CGFloat(cgImage.width) / displaySize.width
        let scaleY = CGFloat(cgImage.height) / displaySize.height
        let cropRect = CGRect(
            x: clampedSelection.minX * scaleX,
            y: clampedSelection.minY * scaleY,
            width: clampedSelection.width * scaleX,
            height: clampedSelection.height * scaleY
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        guard cropRect.width >= 1, cropRect.height >= 1,
              let croppedCGImage = cgImage.cropping(to: cropRect)
        else { return nil }

        let pointWidth = image.size.width * (cropRect.width / CGFloat(cgImage.width))
        let pointHeight = image.size.height * (cropRect.height / CGFloat(cgImage.height))
        let cropped = NSImage(cgImage: croppedCGImage, size: CGSize(width: pointWidth, height: pointHeight))
        cropped.cacheMode = image.cacheMode
        return cropped
    }
}
