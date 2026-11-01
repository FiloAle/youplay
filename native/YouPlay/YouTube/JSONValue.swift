import Foundation

/// Minimal JSON tree. InnerTube responses are deep and change often, so parsers look keys up
/// wherever they appear instead of decoding a fixed structure.
///
/// Built from `JSONSerialization`, which on these large responses is about 8x faster than `Decodable`.
enum JSONValue: Sendable {
	case object([String: JSONValue])
	case array([JSONValue])
	case string(String)
	case bool(Bool)
	case other

	init(data: Data) throws {
		self.init(try JSONSerialization.jsonObject(with: data))
	}

	private init(_ value: Any) {
		switch value {
		case let object as [String: Any]:
			self = .object(object.mapValues(JSONValue.init))
		case let array as [Any]:
			self = .array(array.map(JSONValue.init))
		case let string as String:
			self = .string(string)
		case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
			self = .bool(number.boolValue)
		default:
			self = .other
		}
	}

	subscript(key: String) -> JSONValue? {
		if case .object(let object) = self { object[key] } else { nil }
	}

	var string: String? {
		if case .string(let string) = self { string } else { nil }
	}

	var bool: Bool {
		if case .bool(let bool) = self { bool } else { false }
	}

	var array: [JSONValue] {
		if case .array(let array) = self { array } else { [] }
	}

	/// Every value stored under `key`, at any depth. Arrays keep their order, and matches aren't searched further.
	func all(_ key: String) -> [JSONValue] {
		var results: [JSONValue] = []
		collect(key, into: &results)
		return results
	}

	private func collect(_ key: String, into results: inout [JSONValue]) {
		switch self {
		case .object(let object):
			if let value = object[key] {
				results.append(value)
			} else {
				for value in object.values { value.collect(key, into: &results) }
			}
		case .array(let array):
			for value in array { value.collect(key, into: &results) }
		case .string, .bool, .other:
			break
		}
	}

	func first(_ key: String) -> JSONValue? {
		switch self {
		case .object(let object):
			if let value = object[key] { return value }
			return object.values.lazy.compactMap { $0.first(key) }.first
		case .array(let array):
			return array.lazy.compactMap { $0.first(key) }.first
		case .string, .bool, .other:
			return nil
		}
	}

	/// InnerTube text: `simpleText`, `runs` or `content`.
	var text: String? {
		if let string { return string }
		if let simple = self["simpleText"]?.string { return simple }
		if let content = self["content"]?.string { return content }
		let runs = self["runs"]?.array.compactMap { $0["text"]?.string } ?? []
		return runs.isEmpty ? nil : runs.joined()
	}

	/// InnerTube sorts thumbnail lists by increasing size.
	var largestImageURL: URL? {
		array.last?.imageURL
	}

	var smallestImageURL: URL? {
		array.first?.imageURL
	}

	private var imageURL: URL? {
		guard let raw = self["url"]?.string else { return nil }
		return URL(string: raw.hasPrefix("//") ? "https:" + raw : raw)
	}
}
