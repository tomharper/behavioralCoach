//
//  SpeechMetrics.cpp
//  BehavioralCoachCpp
//
//  Phase 5: scalar speech-metric computation moved out of Swift into C++.
//  Pure standard C++17, no third-party deps, no I/O, no exceptions escape.
//  Internally builds a std::string from the const char* for processing;
//  that detail never appears in the header's ABI.
//

#include "SpeechMetrics.hpp"

#include <string>
#include <cctype>
#include <cstddef>
#include <algorithm>

namespace {

// Lowercase a copy for case-insensitive scanning.
std::string to_lower(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (unsigned char c : s) out.push_back(static_cast<char>(std::tolower(c)));
  return out;
}

bool is_word_char(unsigned char c) {
  // Mirror the Swift split rule: letters, digits, and apostrophe form words.
  return std::isalnum(c) != 0 || c == '\'';
}

// Count non-overlapping occurrences of `needle` in `hay` that sit on word
// boundaries (no word char immediately before/after the match).
//
// NOTE: deviation from Swift. The Swift side uses NSRegularExpression "\b"
// word boundaries on Unicode text. This is a simpler byte-level boundary
// substring scan over UTF-8. For ASCII filler tokens the results match;
// for non-ASCII-adjacent text counts may differ slightly. Acceptable parity
// per Phase 5 spec.
int count_word_matches(const std::string& hay, const std::string& needle) {
  if (needle.empty()) return 0;
  int count = 0;
  std::string::size_type pos = 0;
  while ((pos = hay.find(needle, pos)) != std::string::npos) {
    bool left_ok  = (pos == 0) ||
                    !is_word_char(static_cast<unsigned char>(hay[pos - 1]));
    std::string::size_type end = pos + needle.size();
    bool right_ok = (end >= hay.size()) ||
                    !is_word_char(static_cast<unsigned char>(hay[end]));
    if (left_ok && right_ok) ++count;
    pos = end;
  }
  return count;
}

}  // namespace

namespace coach {

ComputedMetrics compute_metrics(const char* transcript, double durationSeconds) {
  ComputedMetrics m{};
  m.wordsPerMinute      = 0.0;
  m.avgPauseSeconds     = 0.0;   // not knowable from transcript; Phase 6
  m.longestPauseSeconds = 0.0;   // not knowable from transcript; Phase 6
  m.fillerCount         = 0;
  m.sentenceCount       = 0;
  m.avgSentenceWords    = 0.0;

  std::string text = (transcript != nullptr) ? std::string(transcript) : std::string();

  // Word count: split on runs of non-word characters (letters/digits/apostrophe).
  int wordCount = 0;
  bool inWord = false;
  for (unsigned char c : text) {
    if (is_word_char(c)) {
      if (!inWord) { ++wordCount; inWord = true; }
    } else {
      inWord = false;
    }
  }

  // Sentence count: count a terminator only at a real sentence boundary.
  // '!' and '?' always end a sentence. A '.' does not when it sits between
  // two digits (decimals like 3.5, $4.2) and runs of terminators ("..."),
  // are collapsed so an ellipsis counts as a single boundary. This keeps
  // numbers-rich answers (e.g. "3.5s to 1.2s") from inflating the count and
  // driving avgSentenceWords far too low.
  int sentenceCount = 0;
  for (std::size_t i = 0; i < text.size(); ++i) {
    char c = text[i];
    if (c == '!' || c == '?') { ++sentenceCount; continue; }
    if (c == '.') {
      bool digitBefore = i > 0 &&
                         std::isdigit(static_cast<unsigned char>(text[i - 1])) != 0;
      bool digitAfter  = i + 1 < text.size() &&
                         std::isdigit(static_cast<unsigned char>(text[i + 1])) != 0;
      if (digitBefore && digitAfter) continue;            // 3.5 -> not a sentence end
      if (i + 1 < text.size() && text[i + 1] == '.') continue;  // collapse "..."/runs
      ++sentenceCount;
    }
  }

  // Filler count: case-insensitive, word-boundary matches.
  const std::string lower = to_lower(text);
  static const char* const fillers[] = {
    "um", "uh", "like", "basically", "actually",
    "you know", "kind of", "sort of"
  };
  int fillerCount = 0;
  for (const char* f : fillers) {
    fillerCount += count_word_matches(lower, std::string(f));
  }

  m.wordsPerMinute  = (durationSeconds > 0.0)
                        ? static_cast<double>(wordCount) / (durationSeconds / 60.0)
                        : 0.0;
  m.sentenceCount   = sentenceCount;
  m.fillerCount     = fillerCount;
  m.avgSentenceWords =
      static_cast<double>(wordCount) / static_cast<double>(std::max(sentenceCount, 1));

  return m;
}

}  // namespace coach
