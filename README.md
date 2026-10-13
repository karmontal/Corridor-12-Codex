# Corridor 12 — GDD - CODEX

# Corridor 12 — GDD (Notion)

**Version:** v0.1

**Engine:** Godot 4 + GDScript

**Platforms:** PC → Mobile/Tablet

**MVP Timebox:** 2 weeks

## High Concept

Simulation/strategy about planning humanitarian aid convoys under time, safety, and logistics constraints. Optimize **impact, equity, and safety** across a dynamic road network.

## Design Pillars

- **Equity-first distribution**: success requires fair geographic & group coverage.
- **Transparent risk**: readable risk/constraint surfaces; no arbitrary surprises.
- **Short decisions, long impact**: today’s plan shapes tomorrow’s capacity.
- **Simple UI, real depth**: approachable controls with meaningful trade-offs.

## Core Loop

1. **Plan**: set priorities (commodities/areas/convoys), build routes.
2. **Simulate Day**: run the day timeline; fuel/ETA windows; random events.
3. **Deliver & Resolve**: arrivals, holds, reroutes; checkpoint windows.
4. **Assess & Upgrade**: KPIs, equity balance; unlock small improvements.

## Systems

### Map Graph

- **Nodes**: districts / checkpoints / warehouses / distribution points.
- **Edges**: travel time, risk, fuel cost, capacity, time windows.
- **Layers**: risk heatmap, accessibility, congestion.

### Resources

Fuel, drivers (fatigue), vehicle capacity, cold-chain (for meds/fresh food).

### Demand & Equity

- Per-node **Demand** accumulating **Backlog** each day.
- **Equity Index** tracking variance of coverage across areas.

### Events

Small cards modifying windows/risk/fuel/weather for 1–2 days with probabilities.

## KPIs

| KPI | Description |
| --- | --- |
| People Reached | Delivered beneficiaries per day |
| On-Time % | Share of deliveries within windows |
| Incident Count | Security/operational disruptions |
| Equity Variance | Variance of coverage across areas |
| Cold-Chain Breach % | % of cold cargo breaching constraints |
| Fuel/ton-km | Fuel efficiency normalized by ton-km |

## Progression

- Unlocks: better comms, nearer storage, driver training, fleet upgrades.
- Difficulty adds: closed roads → time windows → cold-chain → multi-commodity.

## UX

- **Center**: map with drag-and-drop routing & risk colors.
- **Left**: demand/priorities/resources.
- **Right**: active convoys & schedules.
- **Bottom**: day timeline; play/pause/speed.
- Tooltips, color scales, Undo/Redo.

## Data Examples (JSON)

### Map

```json
{  "nodes": [    {"id":"W1","type":"warehouse","capacity":1000},    {"id":"D1","type":"district","demand":{"food":200,"med":50,"shelter":80}},    {"id":"X1","type":"checkpoint","window":{"start":8,"end":12}}  ],  "edges": [    {"from":"W1","to":"X1","time":20,"risk":0.1,"fuel":5,"capacity":4},    {"from":"X1","to":"D1","time":25,"risk":0.3,"fuel":6,"capacity":2}  ]}
```

### Events

```json
[  {"id":"evt_window_cut","title":"Checkpoint window reduced","effect":{"checkpoint":"X1","end":10},"duration_days":1,"prob":0.2},  {"id":"evt_fuel_shortage","title":"Fuel shortage","effect":{"fuel_multiplier":1.2},"duration_days":2,"prob":0.15}]
```

## Godot Structure (High-level)

```
Main
 ├─ MapRoot (Node2D)
 │   ├─ GraphManager (Node)
 │   ├─ RouteDrawer (Node2D)
 ├─ ConvoyManager (Node)
 ├─ EventManager (Node)
 ├─ SimulationClock (Node)
 ├─ KPITracker (Node)
 ├─ UI (Panels + Timeline)
 └─ Audio
```

## Routing (Multi-criteria)

`cost(edge) = α*time + β*risk + γ*fuel + δ*equity_penalty`

A* over graph; weights configurable; heuristic = time estimate to goal.

## Simulation Tick

- Tick = 1 minute. Update positions, fuel, windows, events, KPIs.
- End-of-day: deliveries applied; backlog updated; KPIs recorded.

## MVP Definition of Done

- Run 3 consecutive days without crashes.
- Complete 3 short scenarios with comparable KPIs.
- In-game tooltips for core concepts.

---

# Databases

corridor12_backlog

## Playable prototype

The repository now includes a Godot 4 prototype. Open `project.godot` in Godot 4.3 or later and press **F6** on `scenes/main.tscn`, or press **F5** to run the project. Choose a district on the map, set cargo and route priority, queue up to two convoys, then simulate the day. The prototype covers three days and offers standard, checkpoint delay, and fuel shortage scenarios.

The map uses shapes drawn in Godot. Higgsfield images and Tripo models can be added later without blocking playtesting of the planning loop.

For a headless gameplay smoke check, run `godot --headless --path . --script res://tests/smoke.gd` from the repository root.

## Download a build

The [Build playable prototype workflow](https://github.com/karmontal/Corridor-12-Codex/actions/workflows/build.yml) tests and exports the game after each push to `main`. Open a completed successful run and download its `Corridor12-playable-builds` artifact. GitHub requires you to be signed in to download workflow artifacts; they are kept for 30 days.

- **Windows:** extract `Corridor12-Windows-x64.zip` and run `Corridor12.exe`. You do not need to install Godot.
- **Android:** download `Corridor12-Android.apk` to an Android 7.0+ ARM phone or tablet, open it, and allow installation from that browser or file manager when Android asks. Play in landscape. The touch interface uses Dispatch, Map and Situation tabs. The APK is development-signed for direct testing; it is not a Google Play release. Installing a build signed with a different development key requires uninstalling the previous app first.
- **Linux:** extract `Corridor12-Linux-x64.zip`, make `Corridor12.x86_64` executable, and run it.
- **Web:** extract `Corridor12-Web.zip`, serve the folder with `python3 -m http.server 8000`, and open `http://localhost:8000` in a WebGL2-capable browser. Opening the HTML directly as a file will not work. This build does not require cross-origin isolation headers.

## Reproduce the build

On Linux, with Bash, curl, Python 3, sha512sum, and ripgrep installed, run:

```bash
bash tools/setup-godot.sh
bash tools/build.sh
```

The setup script pins Godot **4.6.3** and checks the official engine and template archive SHA-512 hashes before installation. Downloads and tool state stay in the ignored `.tools/` directory. The build script imports the project, runs the gameplay smoke checks, exports all three targets, checks that the exported Linux executable starts, and creates ZIP packages with SHA-256 checksums in `build/packages/`. Outputs are ignored by Git.

The Windows build is unsigned. Godot engine license information is included in each package.

For an Android-only build, install a JDK (17 or later), then run:

```bash
bash tools/setup-godot.sh
bash tools/setup-android.sh
bash tools/build-android.sh
```

The Android setup verifies Google's pinned build-tools and platform-tools archives against their official package checksums. Exporting uses the prebuilt Godot APK template, without a Gradle build. A development keystore stays in the ignored `.tools/` directory. CI caches its development key so subsequent CI APKs can update the same installation; cache eviction can require reinstallation. The build checks APK signatures, 16 KB native-library alignment and package/ARM architecture metadata. Set `BUILD_ANDROID=1` when running `tools/build.sh` to include the APK with the other platform packages.
