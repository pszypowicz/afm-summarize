# afm-summarize

Summarize text from stdin into one short sentence, entirely on-device, using Apple's Foundation Models framework (the Apple Intelligence base model). No network calls, no API keys, roughly 1-2 seconds on an M-series Mac.

Built for glanceable one-liners: notification bodies, status bars, tmux panes - anywhere a long blob of text needs to become a single sentence quickly.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon
- Apple Intelligence enabled in System Settings

## Install

```bash
brew install pszypowicz/tap/afm-summarize
```

Or build from source:

```bash
swift build -c release
```

## Usage

```bash
printf '%s' "$LONG_TEXT" | afm-summarize
afm-summarize --max-chars 100 < notes.txt
```

| Flag          | Default | Meaning                                       |
| ------------- | ------- | --------------------------------------------- |
| `--max-chars` | `120`   | Hard cap on the summary length in characters. |

Exit codes:

| Code | Meaning                                                   |
| ---- | --------------------------------------------------------- |
| 0    | Success, summary on stdout                                |
| 64   | Usage error (bad flags, empty stdin)                      |
| 3    | On-device model unavailable (Apple Intelligence disabled) |
| 4    | Generation failed (including safety guardrail refusals)   |

Anything non-zero prints a reason to stderr and nothing to stdout, so pipelines can fall back safely:

```bash
summary="$(printf '%s' "$text" | afm-summarize 2>/dev/null)" || summary="${text:0:120}"
```

## Example: notification pipelines

Turn the tail of a long process log into a notification body:

```bash
tail -n 50 build.log | afm-summarize | xargs -I{} osascript -e 'display notification "{}" with title "Build"'
```

## License

[MIT](LICENSE)
