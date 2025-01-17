import UIKit
import TreeSitterSwift
import SwiftTreeSitter
import Neon

final class ViewController: UIViewController {
	let textView = UITextView()

	lazy var highlighter: TextViewHighlighter = {
		let language = Language(language: tree_sitter_swift())

		let url = Bundle.main
					  .resourceURL?
					  .appendingPathComponent("TreeSitterSwift_TreeSitterSwift.bundle")
					  .appendingPathComponent("queries/highlights.scm")
		let query = try! language.query(contentsOf: url!)

		let regularFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
		let boldFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
		let italicFont = regularFont.fontDescriptor.withSymbolicTraits(.traitItalic).map { UIFont(descriptor: $0, size: 16) } ?? regularFont

		// Set the default styles. This is applied by stock `NSTextStorage`s during
		// so-called "attribute fixing" when you type, and we emulate that as
		// part of the highlighting process in `TextViewSystemInterface`.
		textView.font = regularFont
		textView.textColor = .darkGray

		let provider: TokenAttributeProvider = { token in
			return switch token.name {
			case let keyword where keyword.hasPrefix("keyword"): [.foregroundColor: UIColor.red, .font: boldFont]
			case "comment": [.foregroundColor: UIColor.green, .font: italicFont]
			// Note: Default is not actually applied to unstyled/untokenized text.
			default: [.foregroundColor: UIColor.blue, .font: regularFont]
			}
		}

		return try! TextViewHighlighter(textView: textView,
										language: language,
										highlightQuery: query,
										executionMode: .synchronous,
										attributeProvider: provider)
	}()

	override func viewDidLoad() {
		super.viewDidLoad()

		_ = highlighter.textView

		textView.text = """
		// Example Code!
		let value = "hello world"
		print(value)
		"""

		self.view.addSubview(textView)
		textView.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			textView.leftAnchor.constraint(equalTo: view.leftAnchor),
			textView.rightAnchor.constraint(equalTo: view.rightAnchor),
		])
	}
}

