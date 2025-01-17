import Foundation
import TreeSitterClient
import SwiftTreeSitter

#if os(macOS)
import AppKit

@available(macOS 10.13, *)
public typealias TextStorageEditActions = NSTextStorageEditActions
#elseif os(iOS)
import UIKit

@available(iOS 15.0, tvOS 15.0, *)
public typealias TextStorageEditActions = NSTextStorage.EditActions
#endif

public enum TextViewHighlighterError: Error {
	case noTextStorage
}

#if os(macOS) || os(iOS)
/// A class that can connect `NSTextView`/`UITextView` to `TreeSitterClient`
///
/// This class is a minimal implementation that can help perform highlighting
/// for a TextView. The created instance will become the delegate of the
/// view's `NSTextStorage`.
@available(macOS 10.13, iOS 15.0, tvOS 15.0, *)
@MainActor
public final class TextViewHighlighter: NSObject {
	public let textView: TextView
	private let highlighter: Highlighter
	private let treeSitterClient: TreeSitterClient

	public init(
		textView: TextView,
		client: TreeSitterClient,
		highlightQuery: Query,
		executionMode: TreeSitterClient.ExecutionMode = .asynchronous(prefetch: true),
		interface: TextSystemInterface
	) throws {
		self.treeSitterClient = client
		self.textView = textView

		#if os(macOS)
		guard let storage = textView.textStorage else {
			preconditionFailure("TextView's storage is nil")
		}
		#else
		let storage = textView.textStorage
		#endif

		let textProvider: TreeSitterClient.TextProvider = { range, _ in
			return storage.attributedSubstring(from: range).string
		}

		let tokenProvider = client.tokenProvider(with: highlightQuery, executionMode: executionMode, textProvider: textProvider)

		self.highlighter = Highlighter(textInterface: interface, tokenProvider: tokenProvider)

		super.init()

		storage.delegate = self

		#if os(macOS)
		guard let scrollView = textView.enclosingScrollView else { return }

		NotificationCenter.default.addObserver(self,
											   selector: #selector(visibleContentChanged(_:)),
											   name: NSView.frameDidChangeNotification,
											   object: scrollView)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(visibleContentChanged(_:)),
											   name: NSView.boundsDidChangeNotification,
											   object: scrollView.contentView)
		#else
		highlighter.invalidate(.all)
		#endif

		treeSitterClient.invalidationHandler = { [weak self] in self?.handleInvalidation($0) }

	}

	public convenience init(
		textView: TextView,
		client: TreeSitterClient,
		highlightQuery: Query,
		executionMode: TreeSitterClient.ExecutionMode = .asynchronous(prefetch: true),
		attributeProvider: @escaping TokenAttributeProvider
	) throws {
		let interface = TextViewSystemInterface(textView: textView, attributeProvider: attributeProvider)

		try self.init(
			textView: textView,
			client: client,
			highlightQuery: highlightQuery,
			executionMode: executionMode,
			interface: interface
		)
	}

	public convenience init(
		textView: TextView,
		language: Language,
		highlightQuery: Query,
		executionMode: TreeSitterClient.ExecutionMode = .asynchronous(prefetch: true),
		interface: TextSystemInterface
	) throws {
		let client = try TreeSitterClient(language: language, transformer: { _ in return .zero })

		try self.init(
			textView: textView,
			client: client,
			highlightQuery: highlightQuery,
			executionMode: executionMode,
			interface: interface
		)
	}

	public convenience init(
		textView: TextView,
		language: Language,
		highlightQuery: Query,
		executionMode: TreeSitterClient.ExecutionMode = .asynchronous(prefetch: true),
		attributeProvider: @escaping TokenAttributeProvider
	) throws {
		let client = try TreeSitterClient(language: language, transformer: { _ in return .zero })

		try self.init(
			textView: textView,
			client: client,
			highlightQuery: highlightQuery,
			executionMode: executionMode,
			attributeProvider: attributeProvider
		)
	}

	@objc private func visibleContentChanged(_ notification: NSNotification) {
		highlighter.visibleContentDidChange()
	}

	private func handleInvalidation(_ set: IndexSet) {
		// here is where an HighlightInvalidationBuffer could be handy. Unfortunately,
		// a stock NSTextStorage/NSLayoutManager does not have sufficient callbacks
		// to know when it is safe to mutate the text style.
		DispatchQueue.main.async {
			self.highlighter.invalidate(.set(set))
		}
	}

	/// Perform manual invalidation on the underlying highlighter
	public func invalidate(_ target: TextTarget = .all) {
		highlighter.invalidate()
	}
}

@available(macOS 10.13, iOS 15.0, tvOS 15.0, *)
extension TextViewHighlighter: NSTextStorageDelegate {
	public nonisolated func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: TextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
		assumeMainActor {
			treeSitterClient.willChangeContent(in: editedRange)
		}
	}

	public nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: TextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
		assumeMainActor {
			// Avoid potential infinite loop in synchronous highlighting. If attributes
			// are stored in `textStorage`, that applies `.editedAttributes` only.
			// We don't need to re-apply highlighting in that case.
			// (With asynchronous highlighting, it's not blocking, but also never stops.)
			guard editedMask.contains(.editedCharacters) else { return }
			
			let adjustedRange = NSRange(location: editedRange.location, length: editedRange.length - delta)
			let string = textStorage.string
			
			highlighter.didChangeContent(in: adjustedRange, delta: delta)
			treeSitterClient.didChangeContent(to: string, in: adjustedRange, delta: delta, limit: string.utf16.count)
		}
	}
}

#endif
