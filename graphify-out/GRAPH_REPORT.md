# Graph Report - car-idle  (2026-11-13)

## Corpus Check
- 6 files · ~7,919 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 137 file(s) not represented in the graph (top: .uid 65, .gd 43, .gdshader 16)
- WARNING: 137 of 144 files seen (95%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 170 nodes · 167 edges · 68 communities (6 shown, 62 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.95)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `527da4a7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Car Idle
- steps
- web.yml
- tests
- make_audio.py
- Car Idle
- web_check.js

## God Nodes (most connected - your core abstractions)
1. `main()` - 14 edges
2. `save()` - 13 edges
3. `band()` - 12 edges
4. `noise_loop()` - 10 edges
5. `Car Idle` - 9 edges
6. `sea()` - 8 edges
7. `engine()` - 8 edges
8. `skid()` - 8 edges
9. `water()` - 8 edges
10. `crickets()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Code` --references--> `sea()`  [INFERRED]
  CLAUDE.md → tools/make_audio.py

## Import Cycles
- None detected.

## Communities (68 total, 62 thin omitted)

### Community 1 - "Car Idle"
Cohesion: 0.17
Nodes (10): Agents (.claude/agents/), Car Idle, Code, graphify, Roadmap (GDD), Règles non négociables, Skills (.claude/skills/), Stack (+2 more)

### Community 2 - "steps"
Cohesion: 0.09
Nodes (23): environment, needs, runs-on, steps, GODOT_TPL, GODOT_VERSION, name, url (+15 more)

### Community 6 - "web.yml"
Cohesion: 0.15
Nodes (12): concurrency, cancel-in-progress, group, name, on, push, workflow_dispatch, permissions (+4 more)

### Community 8 - "tests"
Cohesion: 0.11
Nodes (18): GODOT_VERSION, jobs, tests, name, on, pull_request, push, id (+10 more)

### Community 9 - "make_audio.py"
Cohesion: 0.18
Nodes (16): band(), bp_noise(), crickets(), engine(), gravel(), main(), noise_loop(), periodic_lfo() (+8 more)

### Community 13 - "Car Idle"
Cohesion: 0.25
Nodes (7): Car Idle, Jouer sur iPhone, La balade, Monde précalculé, Outils de Claude (facultatif), Ouvrir le projet (PC Windows), Tests

## Knowledge Gaps
- **62 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `sea()` connect `Car Idle` to `make_audio.py`?**
  _High betweenness centrality (0.025) - this node is a cross-community bridge._
- **Should `steps` be split into smaller, more focused modules?**
  _Cohesion score 0.09486166007905138 - nodes in this community are weakly interconnected._
- **Why does `jobs` connect `steps` to `web.yml`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Should `tests` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._