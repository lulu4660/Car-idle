# Graph Report - car-idle  (2026-11-11)

## Corpus Check
- 5 files · ~2,772 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 70 file(s) not represented in the graph (top: .uid 33, .gd 24, .gdshader 7)
- WARNING: 70 of 76 files seen (92%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 137 nodes · 73 edges · 70 communities (8 shown, 62 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `91f02f0b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Car Idle
- steps
- web.yml
- tests
- steps
- deploy
- export
- Car Idle
- web_check.js

## God Nodes (most connected - your core abstractions)
1. `Car Idle` - 9 edges
2. `Car Idle` - 7 edges
3. `steps` - 7 edges
4. `steps` - 7 edges
5. `deploy` - 5 edges
6. `export` - 4 edges
7. `with` - 4 edges
8. `permissions` - 4 edges
9. `tests` - 4 edges
10. `environment` - 3 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (70 total, 62 thin omitted)

### Community 1 - "Car Idle"
Cohesion: 0.20
Nodes (9): Agents (.claude/agents/), Car Idle, Code, graphify, Roadmap (GDD), Règles non négociables, Skills (.claude/skills/), Stack (+1 more)

### Community 2 - "steps"
Cohesion: 0.20
Nodes (11): steps, steps, id, if, name, run, uses, with (+3 more)

### Community 6 - "web.yml"
Cohesion: 0.15
Nodes (12): concurrency, cancel-in-progress, group, name, on, push, workflow_dispatch, permissions (+4 more)

### Community 8 - "tests"
Cohesion: 0.20
Nodes (9): GODOT_VERSION, jobs, tests, name, on, pull_request, push, env (+1 more)

### Community 9 - "steps"
Cohesion: 0.22
Nodes (9): id, if, name, run, uses, with, steps, key (+1 more)

### Community 11 - "deploy"
Cohesion: 0.33
Nodes (6): environment, needs, runs-on, name, url, deploy

### Community 12 - "export"
Cohesion: 0.33
Nodes (6): GODOT_TPL, GODOT_VERSION, env, runs-on, jobs, export

### Community 13 - "Car Idle"
Cohesion: 0.25
Nodes (7): Car Idle, Jouer sur iPhone, La balade, Monde précalculé, Outils de Claude (facultatif), Ouvrir le projet (PC Windows), Tests

## Knowledge Gaps
- **62 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `jobs` connect `export` to `deploy`, `web.yml`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `export` connect `export` to `steps`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `steps` connect `steps` to `export`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._