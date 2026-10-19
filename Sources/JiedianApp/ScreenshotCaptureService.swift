import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenshotCaptureError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case applicationUnavailable
    case captureFailed
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "需要屏幕录制权限才能保存截图。"
        case .displayUnavailable:
            "找不到当前显示器，暂时无法截图。"
        case .applicationUnavailable:
            "无法排除截点面板，请稍后重新截取。"
        case .captureFailed:
            "截图失败，请重试。"
        case .imageEncodingFailed:
            "截图无法保存为图片，请重试。"
        }
    }
}

@MainActor
enum ScreenshotCaptureService {
    static func capturePNG() async throws -> Data {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenshotCaptureError.permissionDenied
        }

        do {
            let shareableContent = try await SCShareableContent.current
            guard let display = currentDisplay(in: shareableContent) else {
                throw ScreenshotCaptureError.displayUnavailable
            }

            let bundleIdentifier = Bundle.main.bundleIdentifier
            let ownApplications = shareableContent.applications.filter {
                $0.bundleIdentifier == bundleIdentifier
            }
            guard !ownApplications.isEmpty else {
                throw ScreenshotCaptureError.applicationUnavailable
            }

            let filter = SCContentFilter(
                display: display,
                excludingApplications: ownApplications,
                exceptingWindows: []
            )
            let configuration = SCStreamConfiguration()
            configuration.width = CGDisplayPixelsWide(display.displayID)
            configuration.height = CGDisplayPixelsHigh(display.displayID)
            configuration.showsCursor = false

            let image: CGImage = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: ScreenshotCaptureError.captureFailed)
                    }
                }
            }

            guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw ScreenshotCaptureError.imageEncodingFailed
            }
            return png
        } catch let error as ScreenshotCaptureError {
            throw error
        } catch {
            if !CGPreflightScreenCaptureAccess() {
                throw ScreenshotCaptureError.permissionDenied
            }
            throw ScreenshotCaptureError.captureFailed
        }
    }

    private static func currentDisplay(in content: SCShareableContent) -> SCDisplay? {
        if let screenNumber = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            if let display = content.displays.first(where: { $0.displayID == displayID }) {
                return display
            }
        }
        return content.displays.first
    }
}
