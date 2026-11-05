import Foundation

enum Format {
	private static let locale = Locale(identifier: "it_IT")

	@MainActor
	private static let relativeFormatter: RelativeDateTimeFormatter = {
		let formatter = RelativeDateTimeFormatter()
		formatter.locale = locale
		formatter.unitsStyle = .full
		return formatter
	}()

	@MainActor
	static func relative(_ date: Date) -> String {
		relativeFormatter.localizedString(for: date, relativeTo: .now)
	}

	/// "LIVE ALLE 21:00" if scheduled for today, otherwise "LIVE IL 25/09".
	static func upcoming(_ date: Date) -> String {
		"LIVE \(startTime(date).uppercased())"
	}

	/// "alle 21:00" if today, otherwise "il 25/09".
	static func startTime(_ date: Date) -> String {
		if Calendar.current.isDateInToday(date) {
			return "alle \(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale)))"
		}
		return "il \(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale)))"
	}

	static func duration(seconds: Int) -> String {
		let (hours, minutes, rest) = (seconds / 3600, seconds % 3600 / 60, seconds % 60)
		let tail = String(format: "%02d", rest)
		return hours > 0
			? "\(hours):\(String(format: "%02d", minutes)):\(tail)"
			: "\(minutes):\(tail)"
	}

	/// "985K visualizzazioni", "7,1 Mln di visualizzazioni": the same wording InnerTube uses.
	static func views(_ count: Int) -> String {
		func compact(_ value: Double) -> String {
			let text = value >= 10 ? String(Int(value)) : String(format: "%.1f", value)
			return text.replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ".", with: ",")
		}
		switch count {
		case ..<1000: return "\(count) visualizzazioni"
		case ..<1_000_000: return "\(compact(Double(count) / 1000))K visualizzazioni"
		default: return "\(compact(Double(count) / 1_000_000)) Mln di visualizzazioni"
		}
	}

	/// Parses InnerTube's "2 settimane fa" or "Trasmesso in streaming 3 giorni fa".
	static func date(fromRelative text: String) -> Date? {
		let units: [(Calendar.Component, [String])] = [
			(.minute, ["minut"]), (.hour, ["ora", "ore"]), (.day, ["giorn"]),
			(.weekOfYear, ["settiman"]), (.month, ["mes"]), (.year, ["ann"]), (.second, ["second"]),
		]
		let lowercased = text.lowercased()
		guard
			let match = lowercased.firstMatch(of: /(\d+)\s+([a-zà-ú]+)\s+fa/),
			let count = Int(match.1)
		else { return nil }
		let word = String(match.2)
		guard let unit = units.first(where: { $0.1.contains(where: word.hasPrefix) })?.0 else { return nil }
		return Calendar.current.date(byAdding: unit, value: -count, to: .now)
	}

	/// Parses "Programmato per il giorno 25/09/26, 16:00" and "Première: 25/09/26, 16:00".
	static func date(fromScheduled text: String) -> Date? {
		let lowercased = text.lowercased()
		guard
			["programmat", "première", "premiere"].contains(where: lowercased.contains),
			let match = lowercased.firstMatch(of: /(\d{1,2})\/(\d{1,2})\/(\d{2,4}),?\s*(\d{1,2}):(\d{2})/),
			let day = Int(match.1), let month = Int(match.2), let rawYear = Int(match.3),
			let hour = Int(match.4), let minute = Int(match.5)
		else { return nil }
		let year = rawYear < 100 ? 2000 + rawYear : rawYear
		return Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
	}
}
