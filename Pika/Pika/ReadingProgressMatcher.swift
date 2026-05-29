//
//  ReadingProgressMatcher.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import Foundation

struct ReadingProgress: Equatable {
    let completedWordCount: Int
    let completedRange: Range<String.Index>?
}

enum ReadingProgressMatcher {
    static func progress(in paragraph: String, transcript: String) -> ReadingProgress {
        let targetWords = words(in: paragraph, keepsRanges: true)
        let spokenWords = words(in: transcript, keepsRanges: false)

        var targetIndex = 0
        var spokenIndex = 0

        while targetIndex < targetWords.count, spokenIndex < spokenWords.count {
            let target = targetWords[targetIndex].normalized
            let spoken = spokenWords[spokenIndex].normalized

            if wordsMatch(target, spoken) {
                targetIndex += 1
                spokenIndex += 1
            } else if targetIndex > 0, wordsMatch(targetWords[targetIndex - 1].normalized, spoken) {
                spokenIndex += 1
            } else {
                break
            }
        }

        guard targetIndex > 0,
              let endIndex = targetWords[targetIndex - 1].range?.upperBound else {
            return ReadingProgress(completedWordCount: 0, completedRange: nil)
        }

        return ReadingProgress(
            completedWordCount: targetIndex,
            completedRange: paragraph.startIndex..<endIndex
        )
    }

    static func wordCount(in text: String) -> Int {
        words(in: text, keepsRanges: false).count
    }

    private static func words(in text: String, keepsRanges: Bool) -> [Word] {
        var words: [Word] = []
        var wordStart: String.Index?

        for index in text.indices {
            if text[index].isLetter || text[index].isNumber {
                wordStart = wordStart ?? index
                continue
            }

            if text[index].isApostropheLike, wordStart != nil {
                continue
            }

            appendWord(from: text, start: &wordStart, end: index, keepsRange: keepsRanges, to: &words)
        }

        appendWord(from: text, start: &wordStart, end: text.endIndex, keepsRange: keepsRanges, to: &words)
        return words
    }

    private static func wordsMatch(_ target: String, _ spoken: String) -> Bool {
        target == spoken || editDistance(target, spoken) <= allowedDistance(for: target, and: spoken)
    }

    private static func allowedDistance(for target: String, and spoken: String) -> Int {
        min(target.count, spoken.count) >= 4 ? 1 : 0
    }

    private static func editDistance(_ first: String, _ second: String) -> Int {
        let first = Array(first)
        let second = Array(second)

        guard !first.isEmpty else { return second.count }
        guard !second.isEmpty else { return first.count }

        var previous = Array(0...second.count)
        var current = Array(repeating: 0, count: second.count + 1)

        for firstIndex in 1...first.count {
            current[0] = firstIndex

            for secondIndex in 1...second.count {
                if first[firstIndex - 1] == second[secondIndex - 1] {
                    current[secondIndex] = previous[secondIndex - 1]
                } else {
                    current[secondIndex] = min(
                        previous[secondIndex] + 1,
                        current[secondIndex - 1] + 1,
                        previous[secondIndex - 1] + 1
                    )
                }
            }

            swap(&previous, &current)
        }

        return previous[second.count]
    }

    private static func appendWord(
        from text: String,
        start: inout String.Index?,
        end: String.Index,
        keepsRange: Bool,
        to words: inout [Word]
    ) {
        guard let wordStart = start, wordStart < end else {
            start = nil
            return
        }

        let original = text[wordStart..<end]
        let normalized = original
            .filter { $0.isLetter || $0.isNumber }
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        guard !normalized.isEmpty else {
            start = nil
            return
        }

        words.append(
            Word(
                normalized: normalized,
                range: keepsRange ? wordStart..<end : nil
            )
        )

        start = nil
    }
}

private struct Word: Equatable {
    let normalized: String
    let range: Range<String.Index>?
}

private extension Character {
    var isApostropheLike: Bool {
        self == "'" || self == "’" || self == "`" || self == "‘"
    }
}
