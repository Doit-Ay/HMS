//
//  PDFCacheManager.swift
//  HMS
//
//  Created on 20/03/26.
//

import Foundation
import PDFKit

/// Caches PDF files on disk so they don't need to be re‑downloaded every time.
/// On open it serves the cached copy instantly, then silently re‑fetches
/// in the background and replaces the cache if the content has changed.
final class PDFCacheManager {

    static let shared = PDFCacheManager()

    private let cacheDir: URL
    private let imageCacheDir: URL
    private let fileManager = FileManager.default

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = caches.appendingPathComponent("PDFCache", isDirectory: true)
        imageCacheDir = caches.appendingPathComponent("ImageCache", isDirectory: true)

        for dir in [cacheDir, imageCacheDir] {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - PDF Public API

    /// Returns a local file URL for the cached PDF (nil if not cached yet).
    func cachedFileURL(for remoteURL: URL) -> URL? {
        let localURL = localPath(for: remoteURL)
        return fileManager.fileExists(atPath: localURL.path) ? localURL : nil
    }

    /// Downloads the PDF from `remoteURL`, saves it to disk, and returns the
    /// local file URL.  If the download fails, returns nil.
    func download(from remoteURL: URL) async -> URL? {
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
            let localURL = localPath(for: remoteURL)

            // Replace any existing cached file
            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: tempURL, to: localURL)

            return localURL
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            return nil
        } catch {
            #if DEBUG
            print("❌ PDFCacheManager download error:", error)
            #endif
            return nil
        }
    }

    /// Checks whether a newer version exists by comparing file sizes.
    /// Downloads the new version and returns `true` if the cache was updated.
    func refreshIfNeeded(from remoteURL: URL) async -> Bool {
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)

            let localURL = localPath(for: remoteURL)

            // Compare sizes to detect changes
            let newSize = try fileManager.attributesOfItem(atPath: tempURL.path)[.size] as? Int ?? 0
            let oldSize = (try? fileManager.attributesOfItem(atPath: localURL.path)[.size] as? Int) ?? -1

            if newSize != oldSize {
                // Content changed — replace cache
                if fileManager.fileExists(atPath: localURL.path) {
                    try fileManager.removeItem(at: localURL)
                }
                try fileManager.moveItem(at: tempURL, to: localURL)
                return true
            } else {
                // No change — clean up temp file
                try? fileManager.removeItem(at: tempURL)
                return false
            }
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            return false
        } catch {
            #if DEBUG
            print("❌ PDFCacheManager refresh error:", error)
            #endif
            return false
        }
    }

    // MARK: - Image Public API

    /// Returns a local file URL for the cached image (nil if not cached yet).
    func cachedImageFileURL(for remoteURL: URL) -> URL? {
        let localURL = imagePath(for: remoteURL)
        return fileManager.fileExists(atPath: localURL.path) ? localURL : nil
    }

    /// Downloads the image from `remoteURL`, saves it to disk, and returns the
    /// local file URL.  If the download fails, returns nil.
    func downloadImage(from remoteURL: URL) async -> URL? {
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
            let localURL = imagePath(for: remoteURL)

            if fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }
            try fileManager.moveItem(at: tempURL, to: localURL)

            return localURL
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            return nil
        } catch {
            #if DEBUG
            print("❌ PDFCacheManager image download error:", error)
            #endif
            return nil
        }
    }

    /// Checks whether a newer image version exists by comparing file sizes.
    /// Downloads the new version and returns `true` if the cache was updated.
    func refreshImageIfNeeded(from remoteURL: URL) async -> Bool {
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)

            let localURL = imagePath(for: remoteURL)

            let newSize = try fileManager.attributesOfItem(atPath: tempURL.path)[.size] as? Int ?? 0
            let oldSize = (try? fileManager.attributesOfItem(atPath: localURL.path)[.size] as? Int) ?? -1

            if newSize != oldSize {
                if fileManager.fileExists(atPath: localURL.path) {
                    try fileManager.removeItem(at: localURL)
                }
                try fileManager.moveItem(at: tempURL, to: localURL)
                return true
            } else {
                try? fileManager.removeItem(at: tempURL)
                return false
            }
        } catch let error as NSError where error.code == NSURLErrorCancelled {
            return false
        } catch {
            #if DEBUG
            print("❌ PDFCacheManager image refresh error:", error)
            #endif
            return false
        }
    }

    // MARK: - General

    /// Clears the entire cache (PDFs + images).
    func clearCache() {
        for dir in [cacheDir, imageCacheDir] {
            try? fileManager.removeItem(at: dir)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Private

    /// Deterministic local path derived from the remote URL (for PDFs).
    private func localPath(for remoteURL: URL) -> URL {
        let hash = remoteURL.absoluteString.data(using: .utf8)!
            .map { String(format: "%02x", $0) }.joined()
        let fileName = String(hash.suffix(40)) + ".pdf"
        return cacheDir.appendingPathComponent(fileName)
    }

    /// Deterministic local path derived from the remote URL (for images).
    private func imagePath(for remoteURL: URL) -> URL {
        let hash = remoteURL.absoluteString.data(using: .utf8)!
            .map { String(format: "%02x", $0) }.joined()
        // Preserve original extension or default to .jpg
        let ext = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension.lowercased()
        let fileName = String(hash.suffix(40)) + ".\(ext)"
        return imageCacheDir.appendingPathComponent(fileName)
    }
}
