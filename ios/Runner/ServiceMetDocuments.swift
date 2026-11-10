import Flutter
import QuickLook
import UIKit
import UniformTypeIdentifiers

/// El mismo contrato de exportación que Android, usando carpetas elegidas en
/// Archivos y bookmarks de iOS. No expone las bases privadas de la aplicación.
final class ServiceMetDocuments: NSObject, UIDocumentPickerDelegate,
  QLPreviewControllerDataSource, QLPreviewControllerDelegate {
  private var directoryResult: FlutterResult?
  private var previewURL: URL?
  private var previewDirectory: URL?
  private var previewHasScope = false
  private let queue = DispatchQueue(label: "bo.metrica.smet.documents", qos: .userInitiated)

  private enum DocumentError: Error {
    case unavailable
    case invalidArguments
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickDirectory":
      guard directoryResult == nil, let presenter = presenter() else {
        result(FlutterError(code: "busy", message: "Cierre el selector abierto e inténtelo de nuevo.", details: nil))
        return
      }
      directoryResult = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
      picker.delegate = self
      picker.allowsMultipleSelection = false
      picker.modalPresentationStyle = .formSheet
      presenter.present(picker, animated: true)
    case "isTreeAvailable":
      perform(result) {
        guard let bookmark = arguments["uri"] as? String else { return false }
        do {
          return try self.withDirectory(bookmark) { directory in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)
              && isDirectory.boolValue
          }
        } catch {
          return false
        }
      }
    case "releaseDirectory":
      // Cada operación abre y libera su propio acceso al bookmark.
      result(nil)
    case "writeDocument", "copyDocument":
      perform(result) {
        guard let bookmark = arguments["treeUri"] as? String,
              let segments = arguments["segments"] as? [String],
              let fileName = arguments["fileName"] as? String else {
          throw DocumentError.invalidArguments
        }
        let components = segments + [fileName]
        return try self.withDirectory(bookmark) { directory in
          // Coordina las escrituras también con proveedores como iCloud Drive.
          var coordinatorError: NSError?
          var writeError: Error?
          NSFileCoordinator().coordinate(writingItemAt: directory, options: .forMerging,
                                         error: &coordinatorError) { coordinatedDirectory in
            do {
              let file = try self.documentURL(in: coordinatedDirectory, components: components)
              try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                      withIntermediateDirectories: true)
              if call.method == "copyDocument" {
                guard let path = arguments["sourcePath"] as? String else {
                  throw DocumentError.invalidArguments
                }
                let source = URL(fileURLWithPath: path).standardizedFileURL
                if source != file.standardizedFileURL {
                  // .atomic conserva la copia anterior si falla la escritura.
                  let data = try Data(contentsOf: source, options: .mappedIfSafe)
                  try data.write(to: file, options: .atomic)
                }
              } else {
                guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else {
                  throw DocumentError.invalidArguments
                }
                try bytes.data.write(to: file, options: .atomic)
              }
            } catch {
              writeError = error
            }
          }
          if let error = coordinatorError { throw error }
          if let error = writeError { throw error }
          // Se conserva el bookmark de la carpeta, no una ruta temporal que
          // pierda el permiso cuando el usuario vuelva a abrir el documento.
          let reference: [String: Any] = ["treeUri": bookmark, "components": components]
          let data = try JSONSerialization.data(withJSONObject: reference)
          return String(decoding: data, as: UTF8.self)
        }
      }
    case "openDocument":
      openDocument(arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = directoryResult
    directoryResult = nil
    guard let directory = urls.first else {
      result?(nil)
      return
    }
    let hasScope = directory.startAccessingSecurityScopedResource()
    defer { if hasScope { directory.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try directory.bookmarkData(options: .minimalBookmark,
                                               includingResourceValuesForKeys: nil, relativeTo: nil)
      result?(["uri": bookmark.base64EncodedString(), "name": directory.lastPathComponent])
    } catch {
      result?(flutterError(error))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let result = directoryResult
    directoryResult = nil
    result?(nil)
  }

  private func resolveDirectory(_ bookmark: String) throws -> URL {
    guard let data = Data(base64Encoded: bookmark) else { throw DocumentError.unavailable }
    var stale = false
    do {
      let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
      guard !stale else { throw DocumentError.unavailable }
      return url
    } catch {
      throw DocumentError.unavailable
    }
  }

  private func withDirectory<T>(_ bookmark: String, action: (URL) throws -> T) throws -> T {
    let directory = try resolveDirectory(bookmark)
    let hasScope = directory.startAccessingSecurityScopedResource()
    defer { if hasScope { directory.stopAccessingSecurityScopedResource() } }
    guard FileManager.default.isWritableFile(atPath: directory.path) else {
      throw DocumentError.unavailable
    }
    return try action(directory)
  }

  private func documentURL(in directory: URL, components: [String]) throws -> URL {
    guard !components.isEmpty, components.allSatisfy({ component in
      !component.isEmpty && component != "." && component != ".."
        && !component.contains("/") && !component.contains("\\")
    }) else { throw DocumentError.invalidArguments }
    let root = directory.standardizedFileURL.resolvingSymlinksInPath()
    let document = components.reduce(root) { $0.appendingPathComponent($1) }
      .standardizedFileURL.resolvingSymlinksInPath()
    guard document.path.hasPrefix(root.path + "/") else { throw DocumentError.invalidArguments }
    return document
  }

  private func perform(_ result: @escaping FlutterResult, action: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try action()
        DispatchQueue.main.async { result(value) }
      } catch {
        let failure = self.flutterError(error)
        DispatchQueue.main.async { result(failure) }
      }
    }
  }

  private func flutterError(_ error: Error) -> FlutterError {
    if case DocumentError.unavailable = error {
      return FlutterError(code: "tree_unavailable",
                          message: "La carpeta ya no está disponible. Selecciónela nuevamente en Archivos.", details: nil)
    }
    return FlutterError(code: "file_error", message: error.localizedDescription, details: nil)
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  private func openDocument(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard previewURL == nil, let presenter = presenter(),
          let reference = arguments["uri"] as? String, let data = reference.data(using: .utf8),
          let document = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          let bookmark = document["treeUri"] as? String,
          let components = document["components"] as? [String] else {
      result(false)
      return
    }
    do {
      let directory = try resolveDirectory(bookmark)
      let hasScope = directory.startAccessingSecurityScopedResource()
      previewDirectory = directory
      previewHasScope = hasScope
      let url = try documentURL(in: directory, components: components)
      guard FileManager.default.fileExists(atPath: url.path),
            QLPreviewController.canPreview(url as NSURL) else {
        releasePreview()
        result(false)
        return
      }
      previewURL = url
      let preview = QLPreviewController()
      preview.dataSource = self
      preview.delegate = self
      presenter.present(preview, animated: true)
      result(true)
    } catch {
      releasePreview()
      result(flutterError(error))
    }
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    return previewURL == nil ? 0 : 1
  }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    return previewURL! as NSURL
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    releasePreview()
  }

  private func releasePreview() {
    if previewHasScope { previewDirectory?.stopAccessingSecurityScopedResource() }
    previewURL = nil
    previewDirectory = nil
    previewHasScope = false
  }
}
