# Graph Report - car-idle  (2026-11-11)

## Corpus Check
- 27 files · ~19,292 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 64 file(s) not represented in the graph (top: .meta 32, .asset 25, .asmdef 4)
- WARNING: 64 of 92 files seen (70%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 678 nodes · 1127 edges · 35 communities (33 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0d1843ea`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Test
- CarController
- manifest.json
- VehicleFactory.Create
- Progression
- CarIdle.Core
- with
- CarEffects
- WorldLayout.Height
- com.unity.render-pipelines.core
- DriveInput
- steps
- packages-lock.json
- Car Idle
- com.unity.settings-manager
- com.unity.test-framework@1.4.6
- CoreTests.csproj
- dependencies
- com.unity.splines@2.8.4
- com.unity.modules.uielements@1.0.0
- com.unity.modules.subsystems@1.0.0
- com.unity.modules.audio@1.0.0
- com.unity.modules.imageconversion
- com.unity.modules.jsonserialize@1.0.0
- com.unity.modules.physics@1.0.0
- com.unity.modules.terrain
- dependencies
- com.unity.ext.nunit
- com.unity.nuget.mono-cecil@1.11.6
- com.unity.profiling.core
- com.unity.burst
- com.unity.collections
- com.unity.modules.imgui@1.0.0
- com.unity.modules.ui@1.0.0
- com.unity.modules.particlesystem

## God Nodes (most connected - your core abstractions)
1. `CarController` - 26 edges
2. `DriveInput` - 22 edges
3. `Progression` - 22 edges
4. `DroneCamera` - 18 edges
5. `WorldBuilder` - 18 edges
6. `CarEffects` - 17 edges
7. `Economy` - 17 edges
8. `ReferenceValuesTests` - 17 edges
9. `WorldLayout` - 15 edges
10. `Surface` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Code` --references--> `Physics2`  [INFERRED]
  CLAUDE.md → Assets/Scripts/Drive/CarController.cs
- `CarController` --references--> `Surface`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Core/WorldLayout.cs
- `BaladeBootstrap` --references--> `CarController`  [EXTRACTED]
  Assets/Scripts/Drive/BaladeBootstrap.cs → Assets/Scripts/Drive/CarController.cs
- `CarController` --references--> `DriveInput`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Drive/DriveInput.cs
- `CarEffects` --references--> `CarController`  [EXTRACTED]
  Assets/Scripts/Drive/CarEffects.cs → Assets/Scripts/Drive/CarController.cs

## Import Cycles
- None detected.

## Communities (35 total, 2 thin omitted)

### Community 0 - "Test"
Cohesion: 0.10
Nodes (3): Economy, ReferenceValuesTests, RulesTests

### Community 1 - "CarController"
Cohesion: 0.08
Nodes (19): CarController, ForwardSpeed, InWater, SlipAngle, SpeedKmh, Drivetrain, AllWheel, FrontWheel (+11 more)

### Community 2 - "manifest.json"
Cohesion: 0.06
Nodes (45): dependencies, com.unity.cinemachine@6.6.0, com.unity.inputsystem@1.20.1, com.unity.modules.adaptiveperformance@1.0.0, com.unity.modules.animation@1.0.0, com.unity.modules.audio@1.0.0, com.unity.modules.imgui@1.0.0, com.unity.modules.jsonserialize@1.0.0 (+37 more)

### Community 4 - "Progression"
Cohesion: 0.09
Nodes (9): CarModel, DisplayName, Catalog, DeterministicRandom, Goal, MissionTemplate, Progression, Series (+1 more)

### Community 5 - "CarIdle.Core"
Cohesion: 0.06
Nodes (10): PartInfo, StageInfo, PostFx, BodyMaterial, RenderSetup, WebBuild, CarIdle.Core, CarIdle.Core.Tests (+2 more)

### Community 6 - "with"
Cohesion: 0.05
Nodes (41): runs-on, steps, concurrency, cancel-in-progress, group, environment, needs, runs-on (+33 more)

### Community 7 - "CarEffects"
Cohesion: 0.10
Nodes (10): Surface, Asphalt, Dirt, Sand, Water, WetSand, CarEffects, HeightField (+2 more)

### Community 9 - "com.unity.render-pipelines.core"
Cohesion: 0.06
Nodes (35): dependencies, depth, source, version, depth, source, version, dependencies (+27 more)

### Community 10 - "DriveInput"
Cohesion: 0.06
Nodes (17): BaladeBootstrap, BaladeHud, DriveInput, Brake, CameraRequested, Handbrake, NextCarRequested, ResetRequested (+9 more)

### Community 11 - "steps"
Cohesion: 0.14
Nodes (13): runs-on, steps, jobs, core-tests, name, on, pull_request, push (+5 more)

### Community 12 - "packages-lock.json"
Cohesion: 0.15
Nodes (13): dependencies, depth, source, version, dependencies, depth, source, version (+5 more)

### Community 13 - "Car Idle"
Cohesion: 0.20
Nodes (9): Assets de boutique (voitures, décors), Car Idle, Essayer la balade (prototype de conduite), Jouer sur iPhone, Outils de Claude (facultatif), Ouvrir le projet (PC Windows), Tests sans Unity, Unity Remote (le plus rapide pour régler la conduite) (+1 more)

### Community 14 - "com.unity.settings-manager"
Cohesion: 0.14
Nodes (14): dependencies, depth, source, version, dependencies, depth, source, url (+6 more)

### Community 15 - "com.unity.test-framework@1.4.6"
Cohesion: 0.18
Nodes (12): dependencies, depth, dependencies, depth, source, version, source, version (+4 more)

### Community 16 - "CoreTests.csproj"
Cohesion: 0.33
Nodes (5): net8.0, Microsoft.NET.Test.Sdk (17.11.1), NUnit (3.14.0), NUnit3TestAdapter (4.6.0), Microsoft.NET.Sdk

### Community 17 - "dependencies"
Cohesion: 0.17
Nodes (12): dependencies, depth, source, version, dependencies, depth, source, version (+4 more)

### Community 18 - "com.unity.splines@2.8.4"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, depth, source, url, version (+3 more)

### Community 19 - "com.unity.modules.uielements@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, url, version, depth, source, version (+3 more)

### Community 20 - "com.unity.modules.subsystems@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 21 - "com.unity.modules.audio@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 22 - "com.unity.modules.imageconversion"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 23 - "com.unity.modules.jsonserialize@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 24 - "com.unity.modules.physics@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 25 - "com.unity.modules.terrain"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 26 - "dependencies"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 27 - "com.unity.ext.nunit"
Cohesion: 0.29
Nodes (7): dependencies, depth, source, version, dependencies, com.unity.ext.nunit, com.unity.ext.nunit

### Community 28 - "com.unity.nuget.mono-cecil@1.11.6"
Cohesion: 0.29
Nodes (7): dependencies, depth, source, url, version, com.unity.nuget.mono-cecil@1.11.6, com.unity.nuget.mono-cecil

### Community 29 - "com.unity.profiling.core"
Cohesion: 0.29
Nodes (7): dependencies, depth, source, url, version, com.unity.profiling.core, com.unity.profiling.core

### Community 30 - "com.unity.burst"
Cohesion: 0.33
Nodes (6): dependencies, depth, source, version, com.unity.burst, com.unity.burst

### Community 31 - "com.unity.collections"
Cohesion: 0.33
Nodes (6): depth, source, version, dependencies, com.unity.collections, com.unity.collections

### Community 32 - "com.unity.modules.imgui@1.0.0"
Cohesion: 0.33
Nodes (6): dependencies, depth, source, version, com.unity.modules.imgui@1.0.0, com.unity.modules.imgui

### Community 33 - "com.unity.modules.ui@1.0.0"
Cohesion: 0.33
Nodes (6): dependencies, depth, source, version, com.unity.modules.ui@1.0.0, com.unity.modules.ui

### Community 34 - "com.unity.modules.particlesystem"
Cohesion: 0.40
Nodes (5): dependencies, depth, source, version, com.unity.modules.particlesystem

## Knowledge Gaps
- **29 isolated node(s):** `Asphalt`, `Dirt`, `Sand`, `WetSand`, `Water` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 270 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dependencies` connect `dependencies` to `com.unity.render-pipelines.core`, `packages-lock.json`, `com.unity.settings-manager`, `com.unity.test-framework@1.4.6`, `dependencies`, `com.unity.splines@2.8.4`, `com.unity.modules.uielements@1.0.0`, `com.unity.modules.subsystems@1.0.0`, `com.unity.modules.audio@1.0.0`, `com.unity.modules.imageconversion`, `com.unity.modules.jsonserialize@1.0.0`, `com.unity.modules.physics@1.0.0`, `com.unity.modules.terrain`, `com.unity.ext.nunit`, `com.unity.nuget.mono-cecil@1.11.6`, `com.unity.profiling.core`, `com.unity.burst`, `com.unity.collections`, `com.unity.modules.imgui@1.0.0`, `com.unity.modules.ui@1.0.0`, `com.unity.modules.particlesystem`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **What connects `Asphalt`, `Dirt`, `Sand` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Test` be split into smaller, more focused modules?**
  _Cohesion score 0.10188261351052048 - nodes in this community are weakly interconnected._
- **Why does `CarIdle.Core` connect `CarIdle.Core` to `Progression`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Should `CarController` be split into smaller, more focused modules?**
  _Cohesion score 0.07807807807807808 - nodes in this community are weakly interconnected._
- **Why does `CarController` connect `CarController` to `DriveInput`, `VehicleFactory.Create`, `CarIdle.Core`, `CarEffects`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Should `manifest.json` be split into smaller, more focused modules?**
  _Cohesion score 0.0647342995169082 - nodes in this community are weakly interconnected._