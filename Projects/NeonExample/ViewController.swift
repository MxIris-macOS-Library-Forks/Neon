import Cocoa
import Neon
import SwiftTreeSitter
import TreeSitterSwift

final class ViewController: NSViewController {
	let textView: NSTextView
	let scrollView = NSScrollView()
	let highlighter: TextViewHighlighter

	init() {
		self.textView = NSTextView()
		textView.isRichText = false  // Discards any attributes when pasting.

		scrollView.documentView = textView
		
		let regularFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
		let boldFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
		let italicFont = NSFont(descriptor: regularFont.fontDescriptor.withSymbolicTraits(.italic), size: 16) ?? regularFont

		// Set the default styles. This is applied by stock `NSTextStorage`s during
		// so-called "attribute fixing" when you type, and we emulate that as
		// part of the highlighting process in `TextViewSystemInterface`.
		textView.typingAttributes = [
			.foregroundColor: NSColor.darkGray,
			.font: regularFont,
		]

		let provider: TokenAttributeProvider = { token in
			return switch token.name {
			case let keyword where keyword.hasPrefix("keyword"): [.foregroundColor: NSColor.red, .font: boldFont]
			case "comment": [.foregroundColor: NSColor.green, .font: italicFont]
			// Note: Default is not actually applied to unstyled/untokenized text.
			default: [.foregroundColor: NSColor.blue, .font: regularFont]
			}
		}

		let language = Language(language: tree_sitter_swift())

		let url = Bundle.main
					  .resourceURL?
					  .appendingPathComponent("TreeSitterSwift_TreeSitterSwift.bundle")
					  .appendingPathComponent("Contents/Resources/queries/highlights.scm")
		let query = try! language.query(contentsOf: url!)

		let interface = TextStorageSystemInterface(textView: textView, attributeProvider: provider)
		self.highlighter = try! TextViewHighlighter(textView: textView,
													language: language,
													highlightQuery: query,
													interface: interface)

		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		let max = CGFloat.greatestFiniteMagnitude

		textView.minSize = NSSize.zero
		textView.maxSize = NSSize(width: max, height: max)
		textView.isVerticallyResizable = true
		textView.isHorizontallyResizable = true

		self.view = scrollView
	}

	override func viewWillAppear() {
		textView.string = """
		// Example Code!
		let value = "hello world"
		print(value)
		"""
	}
}
