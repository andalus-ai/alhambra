# alhambra_lifecycle_store_benchmark

A reproducible, observational comparison of Alhambra's JSONL file and SQLite
lifecycle event stores. It deliberately lives in its own package so neither
storage adapter depends on the other.

## Run

From this package directory:

```sh
dart pub get
dart run benchmark/lifecycle_store_comparison.dart 10000
dart run benchmark/lifecycle_store_comparison.dart 100000
dart run benchmark/lifecycle_store_comparison.dart 1000000
```

The default profile is 10K events. Larger profiles are intended for local
characterization and may take substantial time because both adapters preserve
their normal append durability behavior.

## Methodology

Both adapters receive the same deterministic event sequence and the same
query: owner `owner-7`, successful status, page size 100. The query is warmed
once and then sampled 30 times. The harness reports:

- sequential append duration and events/second;
- filtered query result count and p50/p95 latency;
- total adapter footprint before and after retaining the newest 90% of events;
- compaction duration and removed-event count;
- reopen plus first-query duration;
- SQLite WAL checkpoint counters (JSONL reports checkpointing as not applicable).

The JSONL footprint includes the authoritative log and sparse-index sidecar.
The SQLite footprint includes the database, WAL, and shared-memory files that
exist at measurement time. SQLite maintenance runs a PASSIVE checkpoint after
compaction; the reported footprint after compaction is captured before that
checkpoint so WAL growth remains visible in the comparison.

## Interpretation

This is a same-process comparative harness, not a universal performance
ranking. JSONL is a single-process append-only file adapter with a sparse
sidecar index; SQLite is a transactional database using WAL and indexed
queries. Their durability, indexing, query-planning, and maintenance costs
are intentionally part of the measurement.

Do not compare runs unless the Dart SDK, SQLite version, operating system,
filesystem, storage medium, hardware, power mode, and event count are recorded.
Run each profile multiple times on an otherwise idle machine. Treat the
median of independent runs as more useful than one result. Do not convert
local observations into CI thresholds without a controlled runner and a
separate benchmark-stability study.

The benchmark does not claim cross-process writer safety, power-loss durability,
or memory usage measurements. Those require dedicated tests and platform-
specific instrumentation.
