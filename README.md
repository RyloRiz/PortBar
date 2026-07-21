# PortBar

A macOS menu bar app that watches your machine's listening TCP ports and tells you what's actually running on them.

Built for developers who juggle a dozen local dev servers, databases, and background services, and are tired of running `lsof -i` to remember what's on port 3000 today.

## Features

- **Live port monitoring** — polls listening TCP sockets on a configurable interval (0.75-10s) and shows process name, PID, address, working directory, launch command, parent PID, and elapsed run time for each one.
- **Service catalog** — recognizes 80+ common frameworks and tools out of the box (Vite, Next.js, Postgres, Redis, Docker, Django, FastAPI, Kafka, Supabase, ngrok, and more), each with an icon, tint color, and port/process matching rule.
- **Developer packs** — enable groups of services at once (Frontend web, Backend APIs, Data & queues, Infrastructure, Observability, Mobile, CMS & platforms, Dev utilities) instead of toggling one by one.
- **Quick filters** — pin favorite services to the popup for one-click filtering, with custom rules based on port ranges, process name, or launch command.
- **Pinned ports** — pin specific port numbers to track them even when nothing is currently listening.
- **Process actions** — copy a process's PID or `kill` command, or terminate a process and its full descendant tree directly from the menu.
- **Notifications** — get notified when a service you care about starts or stops listening.
- **Activity history** — a retained log of start/stop events for matched services, with configurable retention.
- **Custom accent color and app icon**, plus a choice of terminal app for "Open in Terminal" actions.

## How it works

PortBar shells out to `lsof -iTCP -sTCP:LISTEN` to enumerate listening sockets, then cross-references `ps` and `lsof -d cwd` to enrich each entry with launch command, parent PID, elapsed time, and working directory. Everything runs locally; PortBar makes no network requests.

## Requirements

- macOS 26.5 or later
- Xcode 26 or later (to build from source)

## Building

```
open PortBar.xcodeproj
```

Then build and run (`⌘R`) the `PortBar` scheme. PortBar is a menu bar-only app (`LSUIElement`), so it won't show a Dock icon or app window — look for its icon in the menu bar.

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

No license has been specified yet.
