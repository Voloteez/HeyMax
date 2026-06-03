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
| **Overlay** | Compact, 5s | Expanded + scrollable, 15s |
| **Trigger** | Any command | "teach", "explain", "how does", etc. |

---

## Conversation Memory

Max keeps the last 10 exchanges in memory. This means:

- **Follow-up questions work** — "explain that again", "go deeper", "what about X?"
- **Context carries over** — you don't have to repeat yourself
- **Multi-turn learning** — have a real back-and-forth conversation about a topic
- **Memory resets** when you restart the app

---

## Architecture

```
heymaxApp.swift       → Menubar-only app, no dock icon
VoiceEngine.swift     → Always-on mic, wake word detection, silence-based command capture
ClaudeAPI.swift       → Smart routing (Haiku/Sonnet), conversation memory, teach detection
ScreenCapture.swift   → ScreenCaptureKit-based screen capture (only when needed)
ActionRunner.swift    → Executes actions: open URLs, launch apps, AppleScript, YouTube, Spotify
OverlayWindow.swift   → Floating overlay UI — compact for actions, expanded for teaching
MenubarView.swift     → Popover UI with start/stop and last command display
```

### Smart Routing

```
User command
    ↓
Detect mode:
    ├── "open spotify"      → Action Mode  → Haiku,  no screenshot,  256 tokens
    ├── "set volume to 30"  → Action Mode  → Haiku,  no screenshot,  256 tokens
    ├── "what's on screen?" → Vision Mode  → Sonnet, + screenshot,   256 tokens
    ├── "explain closures"  → Teach Mode   → Sonnet, + screenshot,  1024 tokens
    └── "go deeper on that" → Teach Mode   → Sonnet, + conversation history
```

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
- **Claude API** — Haiku for fast actions, Sonnet for teaching and vision
- **AppleScript** — deep system automation (volume, dark mode, app control, anything)
- **Conversation memory** — 10-exchange rolling history for natural follow-ups

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
- [ ] Custom wake word
- [ ] Keyboard shortcut trigger
- [ ] Text-to-speech (Max talks back)
- [ ] Plugin system for custom actions
- [ ] Spotify direct playback
- [ ] Persistent settings (auto-start, always listening)
- [ ] Menu bar animation while processing
- [ ] Multi-monitor support
- [ ] Clipboard awareness (teach about copied code)

---

## License

MIT — do whatever you want with it.

---

Built by [@maxim_drd](https://x.com/maxim_drd)
