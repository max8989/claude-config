#!/usr/bin/env python3
"""Normalize a transcript into clean plain text for PRD generation.

Handles the common shapes a recording/transcription tool spits out so the
skill never has to dump a huge raw file into the context window:

  - Whisper-style JSON: {"language","duration","segments":[{"text",...}]}
  - Diarized JSON: segments carry a "speaker" field
  - Generic JSON: a top-level list of segments, or {"results":...} shapes
  - Plain text / markdown (.txt, .md)
  - Subtitles (.srt, .vtt)

Usage:
    python extract_transcript.py <input> [--out <file>] [--speakers]

Prints a short summary (language, duration, word/char count) and writes the
cleaned transcript to <out> (default: <input>.clean.txt next to the source).
The summary is what enters the model's context; the full text stays on disk.
"""
import argparse
import json
import os
import re
import sys


def _clean(text: str) -> str:
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _from_segments(segments, keep_speakers: bool) -> str:
    lines, meta = [], {}
    for seg in segments:
        if not isinstance(seg, dict):
            lines.append(str(seg))
            continue
        txt = (seg.get("text") or seg.get("content") or seg.get("transcript") or "").strip()
        if not txt:
            continue
        spk = seg.get("speaker") or seg.get("speaker_label")
        if keep_speakers and spk:
            lines.append(f"[{spk}] {txt}")
        else:
            lines.append(txt)
    # join sentence-fragment segments with spaces, speaker-tagged ones with newlines
    joiner = "\n" if any(l.startswith("[") for l in lines) else " "
    return joiner.join(lines), meta


def _parse_json(data, keep_speakers: bool):
    meta = {}
    segments = None
    if isinstance(data, dict):
        meta["language"] = data.get("language")
        meta["duration"] = data.get("duration")
        for key in ("segments", "results", "chunks", "utterances", "monologues"):
            if isinstance(data.get(key), list):
                segments = data[key]
                break
        if segments is None and isinstance(data.get("text"), str):
            return _clean(data["text"]), meta
    elif isinstance(data, list):
        segments = data
    if segments is None:
        raise ValueError("Could not locate transcript segments in JSON")
    text, _ = _from_segments(segments, keep_speakers)
    meta["segments"] = len(segments)
    return _clean(text), meta


def _parse_subtitles(raw: str) -> str:
    lines = []
    for line in raw.splitlines():
        s = line.strip()
        if not s or s.isdigit() or s == "WEBVTT":
            continue
        if "-->" in s:
            continue
        lines.append(re.sub(r"<[^>]+>", "", s))  # strip vtt cue tags
    return _clean(" ".join(lines))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--out")
    ap.add_argument("--speakers", action="store_true",
                    help="preserve speaker labels when present")
    args = ap.parse_args()

    path = args.input
    if not os.path.exists(path):
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 1

    ext = os.path.splitext(path)[1].lower()
    with open(path, encoding="utf-8", errors="replace") as f:
        raw = f.read()

    meta = {}
    if ext in (".srt", ".vtt"):
        text = _parse_subtitles(raw)
    else:
        try:
            text, meta = _parse_json(json.loads(raw), args.speakers)
        except (json.JSONDecodeError, ValueError):
            text = _clean(raw)  # treat as plain text

    out = args.out or (os.path.splitext(path)[0] + ".clean.txt")
    with open(out, "w", encoding="utf-8") as f:
        f.write(text + "\n")

    words = len(text.split())
    dur = meta.get("duration")
    print("Transcript normalized.")
    print(f"  source     : {path}")
    print(f"  clean text : {out}")
    if meta.get("language"):
        print(f"  language   : {meta['language']}")
    if dur:
        print(f"  duration   : {round(dur/60, 1)} min")
    if meta.get("segments"):
        print(f"  segments   : {meta['segments']}")
    print(f"  words      : {words}  |  chars: {len(text)}")
    print(f"  est. read  : ~{max(1, round(words/700))} min to read in full")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
