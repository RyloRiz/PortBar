# PortBar

Stop guessing what's on port 3000. PortBar shows you every dev server, database, and daemon in your Mac's Menu Bar.

## Features

- **Live port monitoring** - polls listening TCP sockets on a configurable interval (0.75-10s) and shows process name, PID, address, working directory, launch command, parent PID, and elapsed run time for each one.
- **Service catalog** - recognizes 80+ common frameworks and tools out of the box (Vite, Next.js, Postgres, Redis, Docker, Django, FastAPI, Kafka, Supabase, ngrok, and more), each with an icon, tint color, and port/process matching rule.
- **Developer packs** - enable groups of services at once (Frontend web, Backend APIs, Data & queues, Infrastructure, Observability, Mobile, CMS & platforms, Dev utilities) instead of toggling one by one.
- **Quick filters** - pin favorite services to the popup for one-click filtering, with custom rules based on port ranges, process name, or launch command.
- **Pinned ports** - pin specific port numbers to track them even when nothing is currently listening.
- **Process actions** - copy a process's PID or `kill` command, or terminate a process and its full descendant tree directly from the menu.
- **Notifications** - get notified when a service you care about starts or stops listening.
- **Activity history** - a retained log of start/stop events for matched services, with configurable retention.
- **Custom accent color and app icon**, plus a choice of terminal app for "Open in Terminal" actions.

## How it works

PortBar shells out to `lsof -iTCP -sTCP:LISTEN` to enumerate listening sockets, then cross-references `ps` and `lsof -d cwd` to enrich each entry with launch command, parent PID, elapsed time, and working directory. Everything runs locally; PortBar makes no network requests.

## Built with GPT-5.6 and Codex

PortBar was designed by GPT-5.6 Terra and built by Codex.

Terra started things off by planning the app's internal architecture and drafting the service catalog, working out default ports and matching rules for each framework. From there, I handed things off to the Codex CLI to actually build it: it scaffolded the port monitor and history store, wired up the SwiftUI views, and handled the trickier parts, like safely walking and killing a process tree.

It wasn't a perfectly straight line. There were a few features Terra couldn't quite get right on the first pass, but a round of clarification usually got things back on track. Overall, Terra designed PortBar, and Codex built it.

## Requirements

- macOS 26.5 or later
- Xcode 26 or later (to build from source)

## Building

```
open PortBar.xcodeproj
```

Then build and run (`CMD+R`) the `PortBar` scheme. PortBar is a menu bar-only app (`LSUIElement`), so it won't show a Dock icon or app window - look for its icon in the menu bar.

## Project structure

| File | Responsibility |
|---|---|
| `PortBarApp.swift` | App entry point, wires up the monitor, preferences, notifications, and history |
| `PortMonitor.swift` | Polls `lsof`/`ps` and publishes the current set of listening ports |
| `ServiceCatalog.swift` | Built-in catalog of known services, developer packs, and section groupings |
| `ListenerClassification.swift` | Identifies macOS background daemons to hide by default |
| `PreferencesStore.swift` | Persisted user preferences: quick filters, pinned ports/services, accent color, polling interval |
| `PortNotificationManager.swift` | Sends user notifications for service start/stop events |
| `HistoryStore.swift` | Records and prunes the activity history log |
| `PortBarMenuView.swift` | The menu bar popup UI |
| `SettingsView.swift` | The Settings window (General, Filters, Popup, History, About) |
| `FilterTint.swift` | Maps stored tint strings to `Color` values |

## License

MIT