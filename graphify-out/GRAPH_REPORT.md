# Graph Report - car-idle  (2026-11-11)

## Corpus Check
- 23 files · ~14,001 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 6 file(s) not represented in the graph (top: .asmdef 4, (none) 2)

## Summary
- 373 nodes · 675 edges · 17 communities (15 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.88)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aecec903`
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
- CarModel
- DriveInput
- steps
- web.yml
- Car Idle
- Car Idle
- WebBuild.Build
- CoreTests.csproj

## God Nodes (most connected - your core abstractions)
1. `CarController` - 24 edges
2. `Progression` - 22 edges
3. `DriveInput` - 21 edges
4. `Economy` - 17 edges
5. `CarEffects` - 17 edges
6. `ReferenceValuesTests` - 17 edges
7. `Surface` - 13 edges
8. `WorldLayout` - 13 edges
9. `CarIdle.Core` - 12 edges
10. `RulesTests` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Code` --references--> `Physics2`  [INFERRED]
  CLAUDE.md → Assets/Scripts/Drive/CarController.cs
- `CarController` --references--> `Surface`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Core/WorldLayout.cs
- `BaladeBootstrap` --references--> `DriveInput`  [EXTRACTED]
  Assets/Scripts/Drive/BaladeBootstrap.cs → Assets/Scripts/Drive/DriveInput.cs
- `CarController` --references--> `DriveInput`  [EXTRACTED]
  Assets/Scripts/Drive/CarController.cs → Assets/Scripts/Drive/DriveInput.cs
- `CarEffects` --references--> `CarController`  [EXTRACTED]
  Assets/Scripts/Drive/CarEffects.cs → Assets/Scripts/Drive/CarController.cs

## Import Cycles
- None detected.

## Communities (17 total, 2 thin omitted)

### Community 0 - "Test"
Cohesion: 0.10
Nodes (3): Economy, ReferenceValuesTests, RulesTests

### Community 1 - "CarController"
Cohesion: 0.09
Nodes (10): BaladeBootstrap, BaladeHud, CarController, ForwardSpeed, InWater, SpeedKmh, Physics2, DroneCamera (+2 more)

### Community 2 - "manifest.json"
Cohesion: 0.08
Nodes (35): dependencies, com.unity.cinemachine@3.1.2, com.unity.inputsystem@1.11.2, com.unity.modules.animation@1.0.0, com.unity.modules.audio@1.0.0, com.unity.modules.imgui@1.0.0, com.unity.modules.jsonserialize@1.0.0, com.unity.modules.particlesystem@1.0.0 (+27 more)

### Community 3 - "VehicleFactory.Create"
Cohesion: 0.12
Nodes (4): Materials, IsUrp, VehicleFactory, WorldBuilder

### Community 4 - "Progression"
Cohesion: 0.11
Nodes (6): DeterministicRandom, Goal, MissionTemplate, Progression, Series, Skill

### Community 5 - "CarIdle.Core"
Cohesion: 0.11
Nodes (5): BodyMaterial, CarIdle.Core, CarIdle.Core.Tests, CarIdle.EditorTools, CarIdle.Drive

### Community 6 - "with"
Cohesion: 0.07
Nodes (29): runs-on, steps, environment, needs, runs-on, steps, UNITY_EMAIL, UNITY_LICENSE (+21 more)

### Community 7 - "CarEffects"
Cohesion: 0.16
Nodes (7): Surface, Asphalt, Dirt, Sand, Water, WetSand, CarEffects

### Community 9 - "CarModel"
Cohesion: 0.18
Nodes (5): CarModel, DisplayName, Catalog, PartInfo, StageInfo

### Community 10 - "DriveInput"
Cohesion: 0.20
Nodes (7): DriveInput, Brake, Handbrake, NextCarRequested, ResetRequested, Steer, Throttle

### Community 11 - "steps"
Cohesion: 0.14
Nodes (13): runs-on, steps, jobs, core-tests, name, on, pull_request, push (+5 more)

### Community 12 - "web.yml"
Cohesion: 0.15
Nodes (12): concurrency, cancel-in-progress, group, name, on, push, workflow_dispatch, permissions (+4 more)

### Community 13 - "Car Idle"
Cohesion: 0.22
Nodes (8): Assets de boutique (voitures, décors), Car Idle, Essayer la balade (prototype de conduite), Jouer sur iPhone, Ouvrir le projet (PC Windows), Tests sans Unity, Unity Remote (le plus rapide pour régler la conduite), Version web (Safari), mise en ligne toute seule

### Community 14 - "Car Idle"
Cohesion: 0.25
Nodes (7): Agents (.claude/agents/), Car Idle, graphify, Roadmap (GDD), Règles non négociables, Stack, Vérifier un changement

### Community 16 - "CoreTests.csproj"
Cohesion: 0.33
Nodes (5): net8.0, Microsoft.NET.Test.Sdk (17.11.1), NUnit (3.14.0), NUnit3TestAdapter (4.6.0), Microsoft.NET.Sdk

## Knowledge Gaps
- **21 isolated node(s):** `DisplayName`, `Asphalt`, `Dirt`, `Sand`, `WetSand` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 98 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CarIdle.Core` connect `CarIdle.Core` to `CarModel`, `Progression`?**
  _High betweenness centrality (0.140) - this node is a cross-community bridge._
- **What connects `DisplayName`, `Asphalt`, `Dirt` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Test` be split into smaller, more focused modules?**
  _Cohesion score 0.10188261351052048 - nodes in this community are weakly interconnected._
- **Why does `CarController` connect `CarController` to `DriveInput`, `VehicleFactory.Create`, `CarIdle.Core`, `CarEffects`?**
  _High betweenness centrality (0.086) - this node is a cross-community bridge._
- **Should `CarController` be split into smaller, more focused modules?**
  _Cohesion score 0.0859465737514518 - nodes in this community are weakly interconnected._
- **Why does `DriveInput` connect `DriveInput` to `CarController`, `VehicleFactory.Create`, `CarIdle.Core`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Should `manifest.json` be split into smaller, more focused modules?**
  _Cohesion score 0.08253968253968254 - nodes in this community are weakly interconnected._