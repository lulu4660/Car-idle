# Graph Report - car-idle  (2026-11-11)

## Corpus Check
- 29 files · ~20,476 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 64 file(s) not represented in the graph (top: .meta 32, .asset 25, .asmdef 4)
- WARNING: 64 of 94 files seen (68%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 696 nodes · 1163 edges · 32 communities
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1b37ea13`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Test
- CarController
- manifest.json
- VehicleFactory.Create
- Progression
- unityengine
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
- com.unity.render-pipelines.core
- com.unity.modules.uielements@1.0.0
- com.unity.modules.subsystems@1.0.0
- com.unity.modules.audio@1.0.0
- com.unity.modules.unitywebrequest
- com.unity.modules.jsonserialize@1.0.0
- com.unity.modules.physics@1.0.0
- com.unity.modules.terrain
- com.unity.modules.tetgen
- com.unity.ext.nunit
- com.unity.nuget.mono-cecil@1.11.6
- com.unity.profiling.core
- com.unity.burst
- com.unity.modules.particlesystem

## God Nodes (most connected - your core abstractions)
1. `Progression` - 22 edges
2. `CarController` - 21 edges
3. `CarEffects` - 20 edges
4. `DroneCamera` - 19 edges
5. `DriveInput` - 19 edges
6. `WorldBuilder` - 17 edges
7. `Economy` - 17 edges
8. `ReferenceValuesTests` - 17 edges
9. `WorldLayout` - 15 edges
10. `Materials` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Code` --references--> `Physics2`  [INFERRED]
  CLAUDE.md → Assets/Scripts/Drive/CarController.cs
- `CarController` --references--> `Surface`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Core/WorldLayout.cs
- `CarController` --references--> `DriveInput`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Drive/DriveInput.cs
- `BaladeBootstrap` --references--> `DroneCamera`  [EXTRACTED]
  Assets/Scripts/Drive/BaladeBootstrap.cs → Assets/Scripts/Drive/DroneCamera.cs
- `TerrainImpacts` --references--> `CarEffects`  [EXTRACTED]
  Assets/Scripts/Drive/TerrainImpacts.cs → Assets/Scripts/Drive/CarEffects.cs

## Import Cycles
- None detected.

## Communities (32 total, 0 thin omitted)

### Community 0 - "Test"
Cohesion: 0.11
Nodes (3): Economy, ReferenceValuesTests, RulesTests

### Community 1 - "CarController"
Cohesion: 0.08
Nodes (19): CarController, ForwardSpeed, InWater, SlipAngle, SpeedKmh, Drivetrain, AllWheel, FrontWheel (+11 more)

### Community 2 - "manifest.json"
Cohesion: 0.06
Nodes (45): dependencies, com.unity.cinemachine@6.6.0, com.unity.inputsystem@1.20.1, com.unity.modules.adaptiveperformance@1.0.0, com.unity.modules.animation@1.0.0, com.unity.modules.audio@1.0.0, com.unity.modules.imgui@1.0.0, com.unity.modules.jsonserialize@1.0.0 (+37 more)

### Community 3 - "VehicleFactory.Create"
Cohesion: 0.08
Nodes (5): HeightField, Materials, IsUrp, VehicleFactory, WorldBuilder

### Community 4 - "Progression"
Cohesion: 0.06
Nodes (13): CarModel, DisplayName, Catalog, PartInfo, StageInfo, DeterministicRandom, Goal, MissionTemplate (+5 more)

### Community 5 - "unityengine"
Cohesion: 0.12
Nodes (4): BodyMaterial, GroundTextureImporter, CarIdle.EditorTools, CarIdle.Drive

### Community 6 - "with"
Cohesion: 0.05
Nodes (41): runs-on, steps, concurrency, cancel-in-progress, group, environment, needs, runs-on (+33 more)

### Community 7 - "CarEffects"
Cohesion: 0.07
Nodes (11): BaladeHud, CarEffects, DriveInput, Brake, CameraRequested, Handbrake, NextCarRequested, ResetRequested (+3 more)

### Community 8 - "WorldLayout.Height"
Cohesion: 0.12
Nodes (8): Surface, Asphalt, Dirt, Sand, Water, WetSand, WorldLayout, WorldLayoutTests

### Community 9 - "com.unity.render-pipelines.core"
Cohesion: 0.11
Nodes (19): dependencies, depth, source, version, dependencies, depth, source, url (+11 more)

### Community 10 - "DriveInput"
Cohesion: 0.06
Nodes (11): BaladeBootstrap, DroneCamera, Mode, Chase, Side, Top, Shot, PostFx (+3 more)

### Community 11 - "steps"
Cohesion: 0.14
Nodes (13): runs-on, steps, jobs, core-tests, name, on, pull_request, push (+5 more)

### Community 12 - "packages-lock.json"
Cohesion: 0.17
Nodes (12): dependencies, depth, source, version, dependencies, depth, source, version (+4 more)

### Community 13 - "Car Idle"
Cohesion: 0.20
Nodes (9): Assets de boutique (voitures, décors), Car Idle, Essayer la balade (prototype de conduite), Jouer sur iPhone, Outils de Claude (facultatif), Ouvrir le projet (PC Windows), Tests sans Unity, Unity Remote (le plus rapide pour régler la conduite) (+1 more)

### Community 14 - "com.unity.settings-manager"
Cohesion: 0.08
Nodes (25): dependencies, depth, source, version, dependencies, depth, source, version (+17 more)

### Community 15 - "com.unity.test-framework@1.4.6"
Cohesion: 0.18
Nodes (12): dependencies, depth, dependencies, depth, source, version, source, version (+4 more)

### Community 16 - "CoreTests.csproj"
Cohesion: 0.33
Nodes (5): net8.0, Microsoft.NET.Test.Sdk (17.11.1), NUnit (3.14.0), NUnit3TestAdapter (4.6.0), Microsoft.NET.Sdk

### Community 17 - "dependencies"
Cohesion: 0.11
Nodes (19): dependencies, depth, source, version, dependencies, depth, source, version (+11 more)

### Community 18 - "com.unity.render-pipelines.core"
Cohesion: 0.13
Nodes (16): depth, source, version, dependencies, depth, source, version, dependencies (+8 more)

### Community 19 - "com.unity.modules.uielements@1.0.0"
Cohesion: 0.09
Nodes (22): dependencies, depth, source, url, version, dependencies, depth, source (+14 more)

### Community 20 - "com.unity.modules.subsystems@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 21 - "com.unity.modules.audio@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 22 - "com.unity.modules.unitywebrequest"
Cohesion: 0.40
Nodes (5): dependencies, depth, source, version, com.unity.modules.unitywebrequest

### Community 23 - "com.unity.modules.jsonserialize@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 24 - "com.unity.modules.physics@1.0.0"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 25 - "com.unity.modules.terrain"
Cohesion: 0.18
Nodes (11): dependencies, depth, source, version, dependencies, depth, source, version (+3 more)

### Community 26 - "com.unity.modules.tetgen"
Cohesion: 0.40
Nodes (5): dependencies, depth, source, version, com.unity.modules.tetgen

### Community 27 - "com.unity.ext.nunit"
Cohesion: 0.15
Nodes (13): dependencies, depth, source, version, dependencies, depth, source, version (+5 more)

### Community 28 - "com.unity.nuget.mono-cecil@1.11.6"
Cohesion: 0.29
Nodes (7): dependencies, depth, source, url, version, com.unity.nuget.mono-cecil@1.11.6, com.unity.nuget.mono-cecil

### Community 29 - "com.unity.profiling.core"
Cohesion: 0.29
Nodes (7): dependencies, depth, source, url, version, com.unity.profiling.core, com.unity.profiling.core

### Community 30 - "com.unity.burst"
Cohesion: 0.17
Nodes (12): dependencies, depth, source, version, depth, source, version, dependencies (+4 more)

### Community 34 - "com.unity.modules.particlesystem"
Cohesion: 0.33
Nodes (6): dependencies, depth, source, version, dependencies, com.unity.modules.particlesystem

## Knowledge Gaps
- **29 isolated node(s):** `Chase`, `Side`, `Top`, `IsUrp`, `ForwardSpeed` (+24 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 274 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dependencies` connect `com.unity.modules.particlesystem` to `com.unity.render-pipelines.core`, `packages-lock.json`, `com.unity.settings-manager`, `com.unity.test-framework@1.4.6`, `dependencies`, `com.unity.render-pipelines.core`, `com.unity.modules.uielements@1.0.0`, `com.unity.modules.subsystems@1.0.0`, `com.unity.modules.audio@1.0.0`, `com.unity.modules.unitywebrequest`, `com.unity.modules.jsonserialize@1.0.0`, `com.unity.modules.physics@1.0.0`, `com.unity.modules.terrain`, `com.unity.modules.tetgen`, `com.unity.ext.nunit`, `com.unity.nuget.mono-cecil@1.11.6`, `com.unity.profiling.core`, `com.unity.burst`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **What connects `Chase`, `Side`, `Top` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Test` be split into smaller, more focused modules?**
  _Cohesion score 0.1073170731707317 - nodes in this community are weakly interconnected._
- **Why does `CarController` connect `CarController` to `WorldLayout.Height`, `VehicleFactory.Create`, `unityengine`, `CarEffects`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Should `CarController` be split into smaller, more focused modules?**
  _Cohesion score 0.08067226890756303 - nodes in this community are weakly interconnected._
- **Why does `CarIdle.Core` connect `Progression` to `unityengine`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Should `manifest.json` be split into smaller, more focused modules?**
  _Cohesion score 0.0647342995169082 - nodes in this community are weakly interconnected._