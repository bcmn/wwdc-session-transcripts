#!/usr/bin/swift

import Foundation

// process arguments
enum Mode: String {
    case info, sessions
}

let filename: String
let lineBreak = "\r\n"
let mode: Mode

switch CommandLine.arguments.count {
case 2:
    filename = CommandLine.arguments[1]
    mode = .info
case 3 where Mode(rawValue: CommandLine.arguments[2]) != nil:
    filename = CommandLine.arguments[1]
    mode = Mode(rawValue: CommandLine.arguments[2])!
default:
    print(
        "\nUsage: parse_sessions.swift path [mode]\n" +
            "\n" +
            "Valid modes:\n" +
            "   - sessions\n" +
            "   - info" as String
    )
    exit(0)
}

// load and parse data
func exitWithError(error: String) -> Never {
    print(error)
    exit(1)
}

guard let fileUrl = URL(string: filename),
      let data = try? Data(contentsOf: fileUrl) else {
        exitWithError(error: "Error: Couldn't open '\(filename)'")
}

typealias JSONDict = [String: AnyObject]

guard let
    jsonDict = try! JSONSerialization.jsonObject(with: data, options: []) as? JSONDict,
    let responseDict = jsonDict["response"] as? JSONDict,
    let sessionData = responseDict["sessions"] as? [JSONDict]
    else {
        exitWithError(error: "Error: Couldn't parse JSON in '\(filename)'")
}

/// A single WWDC session
struct Session : CustomStringConvertible {
    var number: Int
    var title: String
    var track: String
    var desc: String

    var description: String {
        let lines = ["\(number):",
            "  :title: \(title)",
            "  :track: \(track)",
            "  :description: \(desc)"
        ]
        return lines.joined(separator: lineBreak)
    }
}



// process JSON into list of sessions
var sessions: [Session] = sessionData
    .filter {
        return ($0["type"] as? String) != "Lab"
    }
    .compactMap {
        guard let numberString = ($0["id"] ?? $0["number"]) as? String
            else { return nil }

        guard let
            type = $0["type"]! as? String,
            let number = Int(numberString),
            let title = $0["title"] as? String,
            let track = $0["track"] as? String,
            let desc = $0["description"] as? String
            else { return nil }

        let filteredTitle = title.replacingOccurrences(of: ":", with: "&#58;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let filteredDesc = desc
            .replacingOccurrences(of: ":", with: "&#58;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        return Session(number: number, title: filteredTitle, track: track, desc: filteredDesc)
}

// derive tracks and types
let tracks = Set(sessions.lazy.map { $0.track })
let types = Set(sessionData.lazy.compactMap { $0["type"] as? String })

// output
switch mode {
case .sessions:
    let sortedSessions = sessions.sorted { $0.number < $1.number }
    print(sortedSessions.map({ "\($0)" }).joined(separator: lineBreak))
case .info:
    print("\(sessions.count) sessions")
    print("Tracks: \(tracks.sorted().joined(separator: ", "))")
    print("Types: \(types.sorted().joined(separator: ", "))")
}
