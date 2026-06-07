# Hey Max 👋

**A voice-controlled AI assistant that lives in your Mac's menubar.**

Say "Hey Max" followed by any command — open apps, play music, control your Mac, learn new things, and more. Max can see your screen, remember conversations, and teach you stuff in real-time. Powered by Claude.

![macOS](https://img.shields.io/badge/macOS-15.0+-black?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift&logoColor=white)
![Claude](https://img.shields.io/badge/Powered%20by-Claude-blueviolet)

---

## How it works

1. **Launch the app** — a waveform icon appears in your menubar
2. **Click it** and hit **Start Listening**
3. **Say "Hey Max"** — a floating overlay appears
4. **Say your command** — pause for 2 seconds
5. **Max responds** — executes the action, answers the question, or teaches you something

No dock icon. No window. Just a menubar icon that's always ready.

---

## What can Max do?

### Open apps
> "Hey Max, open Spotify"
> "Hey Max, open Discord"
> "Hey Max, open Xcode"

### Open websites & dashboards
> "Hey Max, open YouTube"
> "Hey Max, open my RevenueCat dashboard"
> "Hey Max, open GitHub"
> "Hey Max, open Stripe"

### Play music
> "Hey Max, play Back in Black on YouTube"
> "Hey Max, search Thunderstruck on Spotify"

### Control your Mac
> "Hey Max, set volume to 40"
> "Hey Max, toggle dark mode"
> "Hey Max, put my Mac to sleep"

### Ask questions
> "Hey Max, what's 15% of 249?"
> "Hey Max, how do I center a div?"

### Analyze your screen
> "Hey Max, what's on my screen?"
> "Hey Max, what's wrong with this code?"
> "Hey Max, read what's showing"

### Help me with literally anything (NEW)

Max sees your screen and can help with whatever's on it:

**Code & Programming**
> "Hey Max, what's wrong with this code?"
> "Hey Max, explain this function"
> "Hey Max, help me fix this bug"
> "Hey Max, teach me about async await"

**Math & Homework**
> "Hey Max, solve this equation"
> "Hey Max, help me with this problem"
> "Hey Max, is this answer correct?"

**Creative Apps (Lightroom, Figma, Photoshop, etc.)**
> "Hey Max, how do I remove the background in this photo?"
> "Hey Max, I'm lost in Lightroom, help me"
> "Hey Max, what tool should I use for this?"

**Terminal & DevOps**
> "Hey Max, help me set up my terminal"
> "Hey Max, what does this command do?"
> "Hey Max, how do I SSH into a server?"

**Any App**
> "Hey Max, I'm stuck, what should I do?"
> "Hey Max, where do I find settings in this app?"
> "Hey Max, walk me through this"

### Have a conversation (NEW)
Max remembers recent messages — ask follow-ups naturally:
> "Hey Max, what is a closure?"
> *"Hey Max, give me an example"*
> *"Hey Max, explain that last part again"*
> *"Hey Max, now help me with the next step"*

### Run AppleScript (anything)
Max can run any AppleScript command, which means it can control virtually any app on your Mac.

---

## Two Modes

### Action Mode (default)
For quick commands — open apps, play music, set volume, open URLs. Uses **Claude Haiku** for speed. No screenshot captured. Responses are 1-2 sentences. Overlay auto-hides after 5 seconds.

### Teach / Help Mode
Activates when you ask for help, want to learn, or are confused about anything. Uses **Claude Sonnet** for depth. Always captures your screen so Max can reference the **specific things you're looking at** — the exact code, the exact UI, the exact problem. Overlay expands with scrollable content, shows a brain icon, and stays visible for 15 seconds.

Max never gives generic advice when it can see your actual situation. If there's a bug on screen, it points to the exact line. If you're in Lightroom, it tells you exactly which slider to drag.

| | Action Mode | Teach Mode |
|---|---|---|
| **Model** | Claude Haiku (fast) | Claude Sonnet (smart) |
| **Screenshot** | Only when asked | Always (for context) |
| **Response length** | 1-2 sentences | 3-8 sentences, structured |
| **Max tokens** | 256 | 1024 |
| **Overlay** | Compact, 6s | Expanded + scrollable, 20s |
| **Voice** | Speaks response | Speaks full explanation |
| **Trigger** | Any command | "teach", "explain", "help me", "how does", etc. |

---

## Conversation Memory

Max keeps the last 10 exchanges in memory. This means:

- **Follow-up questions work** — "explain that again", "go deeper", "what about X?"
- **Context carries over** — you don't have to repeat yourself
- **Multi-turn learning** — have a real back-and-forth conversation about a topic
- **Memory resets** when you restart the app

---

## Text-to-Speech

Max speaks every response out loud — like having a friend right next to you explaining things.

- Uses **macOS built-in voices** — no API keys, no cost, works offline
- Prefers premium voices (Zoe, Ava, Samantha) when available
- **Toggle voice on/off** anytime from the menubar popover
- Speaks short confirmations for actions, full explanations for teaching

**Better voices:** Go to **System Settings → Accessibility → Spoken Content → System Voice → Manage Voices** and download **Zoe** or **Ava** (Premium). They sound way more natural than the defaults.

---

## Global Hotkey

Press **Option + Space** anywhere to trigger Max — no need to say "Hey Max". Works system-wide, even when the app isn't focused.

- If mic is already listening → goes straight to command capture
- If mic is off → auto-starts listening, then captures command
- Uses Carbon `EventHotKey` API for reliable system-wide capture

---

## Architecture

```
heymaxApp.swift       → Menubar app, no dock icon, global hotkey (Option+Space)
VoiceEngine.swift     → Always-on mic, wake word detection, silence-based capture, manual trigger
ClaudeAPI.swift       → Smart routing, retry logic, request cancellation, system context, safety
ScreenCapture.swift   → ScreenCaptureKit-based capture (half-res, JPEG 0.3 quality for speed)
ActionRunner.swift    → Open URLs, launch apps, AppleScript, YouTube auto-play, Spotify search
OverlayWindow.swift   → Floating overlay — compact for actions, expanded + scrollable for teaching
SpeechOutput.swift    → AVSpeechSynthesizer TTS with premium voice selection
MenubarView.swift     → Popover UI with mic toggle, voice toggle, last command display
```

### Smart Routing

```
User command
    ↓
Sanitize input (trim, cap at 2000 chars)
    ↓
Detect mode:
    ├── "open spotify"      → Action   → Haiku 4.5,  no screenshot,  256 tokens, 15s timeout
    ├── "set volume to 30"  → Action   → Haiku 4.5,  no screenshot,  256 tokens, 15s timeout
    ├── "what's on screen?" → Vision   → Sonnet 4.6, + screenshot,   256 tokens, 15s timeout
    ├── "explain closures"  → Teach    → Sonnet 4.6, + screenshot,  1024 tokens, 30s timeout
    └── "go deeper on that" → Teach    → Sonnet 4.6, + conv history, 1024 tokens, 30s timeout
    ↓
Attach system context (current time, active app, macOS version)
    ↓
Send to Claude API
    ├── Success → parse response + action → show overlay → speak
    ├── 429/5xx → retry with exponential backoff (up to 2 retries)
    ├── 401     → show "Invalid API key" error
    └── Network error → retry, then show error
    ↓
Log: model used, input/output tokens
```

### System Context

Every request includes live context so Claude can adapt:

```
- Current time: Thursday, June 5, 2026 at 2:30 PM
- Active app: Xcode
- macOS version: 15.5
```

This means if you're in Xcode and say "help me with this", Max knows you're coding. If it's 2 AM, it keeps answers brief.

### Retry & Cancellation

| Scenario | Behavior |
|----------|----------|
| Rate limited (429) | Retry after 1.5s, then 3s |
| Server error (5xx) | Retry after 1.5s, then 3s |
| Network failure | Retry after 1s, then 2s |
| New command while processing | Cancel previous request |
| Invalid API key (401) | Show error, no retry |

### Safety

| Layer | Implementation |
|-------|---------------|
| Input sanitization | Trim whitespace, cap at 2000 characters |
| Output sanitization | Strip code fences that confuse TTS |
| Error handling | Proper HTTP status parsing, user-friendly messages |
| Token tracking | Every response logs model + input/output token counts |
| No secrets in prompts | System prompt explicitly forbids outputting passwords/keys |

---

## Setup

### 1. Clone
```bash
git clone https://github.com/Voloteez/heymax.git
cd heymax
```

### 2. Add your Claude API key
Get one at [console.anthropic.com](https://console.anthropic.com/)

In Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**

Add: `ANTHROPIC_API_KEY` = `your-key-here`

### 3. Build & Run
Open `heymax.xcodeproj` in Xcode, hit **Cmd+R**.

### 4. Grant permissions
macOS will ask for:
- **Microphone** — for voice capture
- **Speech Recognition** — for speech-to-text
- **Screen Recording** — for screen capture (teaching + "what's on my screen")

---

## Tech Stack

- **SwiftUI** — menubar UI and floating overlay
- **Speech framework** — on-device speech recognition with wake word detection
- **ScreenCaptureKit** — screen capture for visual analysis and teaching context
- **Claude API** — Haiku 4.5 for fast actions, Sonnet 4.6 for teaching and vision
- **AVSpeechSynthesizer** — built-in macOS text-to-speech with premium voice support
- **Carbon EventHotKey** — system-wide global hotkey (Option+Space)
- **AppleScript** — deep system automation (volume, dark mode, app control, anything)
- **Conversation memory** — 10-exchange rolling history for natural follow-ups
- **Retry logic** — exponential backoff on rate limits and server errors
- **Request cancellation** — new commands cancel in-flight requests

---

## Roadmap

- [x] Voice-activated wake word ("Hey Max")
- [x] Open apps, URLs, and dashboards
- [x] Screen capture and visual analysis
- [x] YouTube search and auto-play
- [x] Spotify search
- [x] System control (volume, dark mode, sleep)
- [x] AppleScript execution (control any app)
- [x] Smart model routing (Haiku vs Sonnet)
- [x] Conversation memory (follow-up questions)
- [x] Teaching mode (detailed explanations, screen context)
- [x] Expandable overlay for long responses
- [x] Text-to-speech (Max talks back with premium macOS voices)
- [x] Voice on/off toggle in menubar
- [x] Global hotkey (Option+Space) — trigger without voice
- [x] System context awareness (current app, time, OS version)
- [x] Latest models (Sonnet 4.6 + Haiku 4.5)
- [x] Retry with exponential backoff on API errors
- [x] Request cancellation (new command cancels old)
- [x] Input/output safety (length limits, sanitization)
- [x] Token usage tracking and logging
### Up Next
- [ ] Streaming responses — text appears word by word in overlay as Claude generates
- [ ] Clipboard awareness — "Hey Max, explain what I just copied"
- [ ] Persistent settings — auto-start on login, always listening, preferred voice
- [ ] Menu bar animation — waveform animates while processing
- [ ] Custom wake word — change "Hey Max" to anything you want

### Short-Term
- [ ] Spotify direct playback via Spotify Connect API
- [ ] Multi-monitor support — overlay follows active screen
- [ ] Chat history panel — browse past conversations in the popover
- [ ] Markdown rendering in overlay — code blocks, bold, lists
- [ ] Sound effects — subtle audio cues for wake word detected, response ready
- [ ] Drag-to-resize overlay — adjust teaching panel size
- [ ] Copy response button — one-click copy from overlay
- [ ] Pin overlay — keep teaching response visible while you work

### Medium-Term
- [ ] Plugin system — custom actions via JSON/Swift config files
- [ ] Shortcuts integration — trigger Apple Shortcuts from voice
- [ ] Calendar awareness — "What's my next meeting?" via EventKit
- [ ] File awareness — "Hey Max, summarize this PDF" (drag & drop or reference by name)
- [ ] Multi-language voice — detect and respond in French, Spanish, etc.
- [ ] ElevenLabs TTS option — premium voice quality for power users
- [ ] Local LLM fallback — Ollama/llama.cpp when offline (no API needed)
- [ ] Notification actions — "Read my latest Slack message", "What did I miss?"

### Long-Term Vision
- [ ] Always-on ambient mode — Max listens passively, offers help proactively ("I noticed an error on your screen")
- [ ] Workflow recording — "Hey Max, watch what I do and remember it" → replayable macros
- [ ] Screen region selection — highlight a portion of screen to ask about
- [ ] Multi-app orchestration — "Move this Figma design into a new Notion page"
- [ ] Voice cloning — Max sounds like you (or anyone you choose)
- [ ] iOS companion app — continue conversations from your phone
- [ ] Team mode — shared knowledge base for dev teams ("How does our auth flow work?")
- [ ] MCP integration — connect to any tool via Model Context Protocol
- [ ] App Store release — signed, notarized, auto-update via Sparkle

---

## License

MIT — do whatever you want with it.

---

Built by [@maxim_drd](https://x.com/maxim_drd)
