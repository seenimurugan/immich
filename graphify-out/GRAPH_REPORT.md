# Graph Report - immich  (2026-05-30)

## Corpus Check
- 33 files · ~10,303 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 196 nodes · 163 edges · 33 communities (25 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `03838ad1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]

## God Nodes (most connected - your core abstractions)
1. `Immich Bulk Upload — runbook` - 14 edges
2. `Immich — Architecture & Tech Stack` - 11 edges
3. `Immich upgrade runbook — v2.6.3 → v2.7.5` - 11 edges
4. `Immich — User Manual` - 8 edges
5. `immich` - 7 edges
6. `!! NON-PORTABLE BITS — read before deploying on a new machine/cluster !!` - 7 edges
7. `Immich — Deployment & Maintenance` - 7 edges
8. `Troubleshooting` - 7 edges
9. `code-review-graph` - 6 edges
10. `Common operations` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (33 total, 8 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.11
Nodes (18): Backup, Common operations, Deploy / redeploy, Immich — Deployment & Maintenance, Immich pod CrashLoopBackOff, Localhost returns HTTP 000, Logs, Machine-learning pod restarting (+10 more)

### Community 1 - "Community 1"
Cohesion: 0.13
Nodes (14): After upload — watch ML jobs drain, Auto-create albums from folder names, Basic upload (single folder), Bulk upload from external HDD, Duplicate detection (run AFTER bulk uploads), Google Takeout exports (zipped photos), Immich Bulk Upload — runbook, Long-running uploads — run in background (+6 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (13): 0. Pre-flight checks, 1. Backup BEFORE upgrade (mandatory), 2. Check what target version is safe, 3. Bump image tags (kubectl set image — simple, bypasses helm), 4. Watch the migration, 5. Refresh port-forward (immich-server got recreated), 6. Verify, 7. If something goes wrong — rollback (+5 more)

### Community 3 - "Community 3"
Cohesion: 0.14
Nodes (13): 1. PVC UUID — `immich-upload-localpath-pvc` (HIGH PRIORITY), 2. HDD paths (machine-specific), 3. Storage-tier symlinks, 4. Postgres DB is NOT on the HDD, 5. Tailscale ingress hostname, 6. OrbStack HDD mount fd limit, Access, Depends on (+5 more)

### Community 4 - "Community 4"
Cohesion: 0.17
Nodes (11): Config files (this repo), Data layout, Design decisions, Immich — Architecture & Tech Stack, Reference, Source code, Storage tier (cluster-setup repo), Tech stack (+3 more)

### Community 5 - "Community 5"
Cohesion: 0.22
Nodes (8): Add family members, Browse & search, Bulk upload from the Mac (CLI), Immich — User Manual, Initial setup (first visit), Mobile app — auto-backup from iPhone/Android, Sharing, Upgrade Immich to a newer version

### Community 6 - "Community 6"
Cohesion: 0.25
Nodes (7): args, command, cwd, env, type, mcpServers, code-review-graph

### Community 7 - "Community 7"
Cohesion: 0.40
Nodes (4): Debug Issue, Steps, Tips, Token Efficiency Rules

### Community 8 - "Community 8"
Cohesion: 0.40
Nodes (4): Explore Codebase, Steps, Tips, Token Efficiency Rules

### Community 9 - "Community 9"
Cohesion: 0.40
Nodes (4): Refactor Safely, Safety Checks, Steps, Token Efficiency Rules

### Community 10 - "Community 10"
Cohesion: 0.40
Nodes (4): Output Format, Review Changes, Steps, Token Efficiency Rules

### Community 11 - "Community 11"
Cohesion: 0.40
Nodes (4): Debug Issue, Steps, Tips, Token Efficiency Rules

### Community 12 - "Community 12"
Cohesion: 0.40
Nodes (4): Explore Codebase, Steps, Tips, Token Efficiency Rules

### Community 13 - "Community 13"
Cohesion: 0.40
Nodes (4): Refactor Safely, Safety Checks, Steps, Token Efficiency Rules

### Community 14 - "Community 14"
Cohesion: 0.40
Nodes (4): Output Format, Review Changes, Steps, Token Efficiency Rules

### Community 15 - "Community 15"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 16 - "Community 16"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 17 - "Community 17"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 18 - "Community 18"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 19 - "Community 19"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 20 - "Community 20"
Cohesion: 0.40
Nodes (4): Key Tools, MCP Tools: code-review-graph, When to use graph tools FIRST, Workflow

### Community 21 - "Community 21"
Cohesion: 0.50
Nodes (3): hooks, PostToolUse, SessionStart

### Community 22 - "Community 22"
Cohesion: 0.50
Nodes (3): Access, Detailed docs, Immich — photo server

### Community 23 - "Community 23"
Cohesion: 0.50
Nodes (3): hooks, AfterTool, SessionStart

### Community 24 - "Community 24"
Cohesion: 0.50
Nodes (3): hooks, PostToolUse, SessionStart

## Knowledge Gaps
- **130 isolated node(s):** `setup-graph.sh script`, `command`, `args`, `cwd`, `type` (+125 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `setup-graph.sh script`, `command`, `args` to the rest of the system?**
  _130 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._