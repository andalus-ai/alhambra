# Alhambra (الجبر) — Autonomous AI Coding & Engineering Substrate

> **Alhambra (Algebra / Restoration)** is a local-first, autonomous software engineering platform built on the Andalus Platform framework. It synthesizes the interactive ergonomics of **Codex / Cursor**, the autonomous planning and verification rigor of **Google Antigravity**, and the deterministic tool orchestration and execution safety of **Claude Code**.

---

## 🌟 Executive Synthesis: Codex + Antigravity + Claude Code

Alhambra bridges the gap between interactive IDE assistants and fully autonomous agent loops:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                ALHAMBRA UNIFIED SUBSTRATE                                │
├─────────────────────────┬─────────────────────────────┬────────────────────────────────┤
│   CODEX / CURSOR UX     │     ANTIGRAVITY RIGOR       │        CLAUDE CODE SAFETY      │
├─────────────────────────┼─────────────────────────────┼────────────────────────────────┤
│ • Side-by-side Diff     │ • Adaptive Reasoning Gate   │ • Semantic Tool Orchestrator   │
│ • Context Chips (@file) │ • Graduated Verify Ladder   │ • Confined Process Sandbox     │
│ • Real-time Streaming   │ • Closed-Loop Self-Repair   │ • Human-in-the-Loop Gateways   │
│ • Line-level Jump-links │ • Structured Step Checklist │ • Deterministic Diagnostics    │
│ • Problems / Sonar Tab  │ • Transactional Rollbacks   │ • Multi-Language Auto-Detect   │
└─────────────────────────┴─────────────────────────────┴────────────────────────────────┘
```

---

## 🏛 Architecture & Building Blocks

Alhambra operates across three coordinated tiers:
1. **Frontend Tier (`alhambra_gui`)**: A desktop IDE interface written in Flutter (Riverpod state management) providing side-by-side Code/Diff/Terminal/Problems views, context pinning (`@` mentions), live plan tracking, and verification status badges.
2. **Backend Engine Tier (`alhambra-engine` & `alhambra-api`)**: A reactive Quarkus service (Java 25) implementing the cognitive lifecycle: Reasoning Gate $\to$ Context Planning $\to$ Mutation Engine $\to$ Verification Ladder $\to$ Closed-Loop Autonomous Repair.
3. **LSP & Tool Substrate (`muqabala`)**: A headless LSP and Debug Adapter Protocol (DAP) kernel managing language servers, symbol tables, Open VSX extensions, and AST indexers.

```mermaid
graph TB
    subgraph Frontend ["Desktop GUI (Flutter / Riverpod)"]
        UI_Chat["Chat & Plan Stream"]
        UI_Editor["Code Editor & Line Highlighting"]
        UI_Diff["Side-by-Side Diff Inspector"]
        UI_Terminal["Interactive Terminal Shell"]
        UI_Problems["Problems & Sonar Quality Gate"]
    end

    subgraph BackendEngine ["Alhambra Backend Engine (Java 25 / Quarkus)"]
        RG["Reasoning Gate & Skill Router"]
        CE["Context Engine & Budget Planning"]
        ME["Transactional Mutation Engine"]
        VE["Verification Engine (L0-L5 Ladder)"]
        CL["Closed-Loop Autonomous Repair"]
        TO["Semantic Tool Orchestrator"]
        WI["Workspace Indexer & Symbol Graph"]
    end

    subgraph Substrate ["Infrastructure & Toolchains"]
        LSP["Muqabala LSP Kernel (gRPC / WS)"]
        TC["Multi-Language Toolchains (Maven, CMake, SwiftPM, Xcode, Flutter, Sonar)"]
        SANDBOX["Confined Process Sandbox & Tool Policy"]
    end

    UI_Chat <-->|gRPC / Stream| BackendEngine
    UI_Problems <-->|State Notifiers| BackendEngine
    UI_Editor <-->|File Buffers| BackendEngine
    
    BackendEngine <-->|Language Server Protocol| LSP
    TO -->|Sandboxed Execution| TC
    TO -->|Security Gates| SANDBOX
    CL -->|Auto Repair Loop| VE
    VE -->|Test / Diagnostic Feedback| CE
```

---

## 🧩 Component Specifications

```mermaid
classDiagram
    class ReasoningGate {
        +evaluate(TaskContext) ReasoningDecision
    }
    class WorkspaceIndexer {
        +index(Path) WorkspaceKnowledge
    }
    class ContextEngine {
        +planContext(Task, Budget) ContextPlan
        +assemble(ContextPlan) ContextPacket
    }
    class MutationEngine {
        +apply(EditProposal, Path) WorkspaceFingerprint
        +rollback(WorkspaceFingerprint) void
    }
    class VerificationEngine {
        +verify(Fingerprint, Proposal, Level) VerificationResult
        +runTargetedTests(String, Path) VerificationResult
    }
    class ClosedLoopCoder {
        +executeLoop(ContextPlan, maxAttempts) RepairResult
    }
    class ToolOrchestrator {
        +executeIntent(ToolIntent, Path) ExecutionResult
    }
    class OutputProcessor {
        +process(exitCode, stdout, stderr) ProcessedOutput
    }

    ReasoningGate --> ContextEngine
    ContextEngine --> ClosedLoopCoder
    ClosedLoopCoder --> MutationEngine
    ClosedLoopCoder --> VerificationEngine
    ClosedLoopCoder --> ToolOrchestrator
    ToolOrchestrator --> OutputProcessor
    WorkspaceIndexer --> ContextEngine
```

| Component | Responsibility | Key Classes / Interfaces |
| :--- | :--- | :--- |
| **Reasoning Gate** | Analyzes task complexity and dynamically selects whether to use direct reactive tools, single-step execution, or multi-step autonomous planning. | [`ReasoningGate`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/skill/routing/ReasoningGate.java), [`SkillSelector`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/skill/routing/SkillSelector.java) |
| **Workspace Indexer** | Parses ASTs, indexes symbol definitions, references, call graphs, and dependency relationships across workspace files. | [`WorkspaceIndexer`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/index/indexer/WorkspaceIndexer.java), [`RelationIndex`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/index/RelationIndex.java) |
| **Context Engine** | Constructs budget-constrained prompt context packets with deterministic prioritization (active file $\to$ symbols $\to$ dependencies $\to$ related files $\to$ recent failure traces). | [`ContextEngine`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/context/DefaultContextEngine.java), [`ContextBudgeter`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/context/ContextBudgeter.java) |
| **Mutation Engine** | Applies atomic file edits, unified diffs, and AST replacements with transactional rollback checkpoints (`WorkspaceFingerprint`). | [`MutationEngine`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/patch/mutation/MutationEngine.java) |
| **Verification Engine** | Executes a graduated 6-tier verification ladder (L0: Syntax $\to$ L1: Sonar Lint & Security $\to$ L2: Targeted Tests $\to$ L3: Affected Callers $\to$ L4: Module Tests $\to$ L5: Full Suite). | [`VerificationEngine`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/verification/VerificationEngine.java), [`DefaultVerificationEngine`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/verification/DefaultVerificationEngine.java) |
| **Closed-Loop Coder** | Coordinates the self-healing cycle: Generates patch $\to$ applies mutation $\to$ verifies $\to$ if failed, rolls back and re-prompts with extracted diagnostics until success. | [`ClosedLoopCoder`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/repair/DefaultClosedLoopCoder.java) |
| **Tool Orchestrator** | Discovers workspace toolchains and maps high-level intents (`BUILD`, `RUN_TEST`, `FORMAT`, `LINT`, `STATIC_ANALYSIS`) to sandboxed execution commands. | [`ToolOrchestrator`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/orchestrator/ToolOrchestrator.java), [`ToolPolicy`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/orchestrator/policy/ToolPolicy.java) |
| **Output Processor** | Ingests raw terminal output, compiler logs (`javac`, `clang`, `swiftc`), test assertions (`JUnit`, `ctest`, `XCTest`), and OASIS standard SARIF JSON reports into structured `ExecutionDiagnostic` records. | [`OutputProcessor`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/orchestrator/output/OutputProcessor.java), [`SarifReportParser`](file:///Users/bhangun/Workspace/workkayys/Products/Andalus/andalus-platform/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine/src/main/java/tech/kayys/alhambra/engine/orchestrator/output/SarifReportParser.java) |

---

## 🔄 End-to-End Sequence Diagrams

### 1. Autonomous Coding & Closed-Loop Repair Loop

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer / UI
    participant RG as ReasoningGate
    participant CE as ContextEngine
    participant LLM as Model / LLM (Local / Cloud)
    participant ME as MutationEngine
    participant VE as VerificationEngine
    participant TO as ToolOrchestrator

    Dev->>RG: Prompt: "Fix authentication token validation in AuthService"
    RG->>CE: Request Context Plan (Budget: 8192 tokens)
    CE->>CE: Assemble active file, symbol refs, call hierarchy
    CE-->>RG: Structured ContextPacket
    RG->>LLM: Inference Request with ContextPacket
    LLM-->>RG: Generated EditProposal (FileEdits + TextEdits)

    loop Autonomous Repair Loop (Attempts 1..N)
        RG->>ME: Apply EditProposal (Create WorkspaceFingerprint)
        ME-->>RG: Checkpoint Created
        RG->>VE: Verify(Level: L1 Static Analysis + L2 Targeted Tests)
        
        alt Verification Passed
            VE-->>RG: VerificationResult(SUCCESS, Level: L2)
            RG->>Dev: Stream Plan Completion & Diffs
        else Verification Failed (e.g. Compiler Error or Test Assertion)
            VE->>TO: Extract Diagnostics from OutputProcessor
            TO-->>VE: List<ExecutionDiagnostic> (File, Line, Message)
            VE-->>RG: VerificationResult(FAILED, TestFailureSummary)
            RG->>ME: Rollback to Checkpoint Fingerprint
            ME-->>RG: Clean Pre-Mutation Workspace Restored
            RG->>CE: Inject Failure Traces into Next Context Packet
            CE-->>RG: Updated ContextPacket with Error Diagnostics
            RG->>LLM: Re-prompt: "Attempt failed at AuthService.java:42. Fix diagnostics..."
        end
    end
```

---

### 2. Multi-Language Toolchain Orchestration & Sandboxed Execution

```mermaid
sequenceDiagram
    autonumber
    participant Agent as Alhambra Engine
    participant Detector as DefaultProjectDetector
    participant Resolver as DefaultToolResolver
    participant Policy as ToolPolicy Safety Gate
    participant Exec as DefaultExecutionEngine
    participant Output as DefaultOutputProcessor

    Agent->>Detector: detect(workspaceRoot)
    Detector-->>Agent: ProjectToolchain(BuildSystem: CMAKE, Languages: [C, C++])
    
    Agent->>Resolver: resolve(ToolIntent: BUILD, Toolchain)
    Resolver-->>Agent: ResolvedTool(command: ["cmake", "--build", "build"], sandboxed: true)
    
    Agent->>Policy: evaluate(ToolIntent, ResolvedTool, workspaceRoot)
    Policy-->>Agent: ToolPolicyDecision(ALLOWED)
    
    Agent->>Exec: execute(ResolvedTool, timeout: 30s)
    Exec->>Exec: Run confined sub-process with bounded output buffer
    Exec-->>Output: Process exitCode, stdout, stderr
    Output->>Output: Match Clang/GCC/SARIF diagnostic regexes
    Output-->>Agent: ProcessedOutput(status: BUILD_FAILURE, diagnostics: [...])
```

---

### 3. Human-in-the-Loop Approval & Interactive Security Gate

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer / User
    participant UI as Flutter GUI (alhambra_gui)
    participant Agent as Alhambra Engine
    participant Policy as ToolPolicy Gate
    participant Sandbox as Sandbox Process Runner

    Agent->>Policy: Evaluate command (e.g. `rm -rf build` or `git push --force`)
    Policy-->>Agent: Decision: REQUIRES_HUMAN_APPROVAL (Risk: HIGH / CRITICAL)
    Agent->>UI: Emit ApprovalRequestCard(id, command, risk, reason)
    UI->>Dev: Display inline approval card with command diff & risk badge
    
    alt User Clicks Approve
        Dev->>UI: Click "Approve & Run"
        UI->>Agent: resolveApproval(id, approved: true)
        Agent->>Sandbox: Execute command in sandbox
        Sandbox-->>Agent: Command output
        Agent->>UI: Update status: APPROVED & show output
    else User Clicks Deny
        Dev->>UI: Click "Deny"
        UI->>Agent: resolveApproval(id, approved: false)
        Agent->>Agent: Abort command execution safely
        Agent->>UI: Update status: DENIED
    end
```

---

## 🛠 Supported Build Systems & Multi-Language Toolchains

Alhambra automatically discovers project toolchains and executes builds, tests, formatting, linting, and static analysis without manual script configuration:

| Build System | Languages | Build Command | Test Command | Format / Lint Command | Static Analysis / SARIF |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Maven** | Java, Kotlin | `mvn compile -DskipTests` | `mvn test -Dtest=...` | `mvn spotless:apply` / `checkstyle` | `sonar-scanner` / `SpotBugs` |
| **Gradle** | Java, Kotlin, Groovy | `./gradlew assemble` | `./gradlew test --tests ...` | `./gradlew ktlintFormat` | `sonar-scanner` / Detekt |
| **CMake** | C, C++ | `cmake --build build` | `ctest --test-dir build -R ...` | `clang-format -i` / `clang-tidy` | `sonar-scanner` / `cppcheck` |
| **Make / Meson**| C, C++ | `make` / `meson compile` | `make test` / `meson test` | `clang-format -i` | `sonar-scanner` |
| **Swift PM** | Swift | `swift build` | `swift test --filter ...` | `swift-format -i` / `swiftlint` | `swiftlint --reporter sarif` |
| **Xcode** | Swift, Objective-C | `xcodebuild build` | `xcodebuild test -only-testing:...` | `clang-format -i` (ObjC) | `sonar-scanner` / `swiftlint` |
| **Flutter** | Dart | `flutter build` | `flutter test <path>` | `dart format` / `dart analyze` | `dart analyze` |
| **Cargo** | Rust | `cargo build` | `cargo test <name>` | `cargo fmt` / `cargo clippy` | `cargo clippy --message-format=json` |
| **Go** | Go | `go build ./...` | `go test -run ...` | `gofmt -w` / `golangci-lint` | `golangci-lint run --out-format sarif` |
| **Python** | Python | `python -m build` | `pytest -k ...` | `black` / `ruff` | `bandit -f json` / `ruff --output-format=sarif` |

---

## 🚀 Building & Running

### Prerequisites
- **JDK 25** (with Maven 3.9+)
- **Flutter SDK 3.x+**
- **Docker** (optional, for sandboxed container isolation)

### 1. Build Backend & LSP Kernel
```bash
# Build headless LSP Kernel (Muqabala)
cd Andalus-Projects/Utilities/muqabala
mvn clean package -DskipTests

# Build Alhambra Engine & API
cd ../../Andalus-Agents/Alhambra/Backend
mvn clean package -DskipTests
```

### 2. Run Automated Verification Tests
```bash
# Run all Alhambra backend unit & integration tests (40/40 tests)
cd Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-engine
mvn test

# Run Flutter GUI unit & widget tests (10/10 tests)
cd ../../alhambra_gui
flutter test
```

### 3. Launch Desktop Application
```bash
# Start Backend Service (Quarkus Dev Mode with Live Reload)
cd Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-api
mvn quarkus:dev

# Start Flutter Desktop GUI
cd ../alhambra_gui
flutter run -d macos # or -d linux, -d windows
```

---


## FAQ

### Why used gollek run instead of grpc?
Ran command: `grep -rnwi "grpc" .`
Ran command: `find . -name "*.java"`
Viewed GollekProvider.java:1-44
Ran command: `cat ./src/main/java/tech/kayys/andalus/provider/gollek/GollekInferenceProvider.java | grep -n "implements InferenceProvider"`
Ran command: `grep -rnwi "GollekInferenceProvider" ../../../../`
Ran command: `cat /Users/bhangun/.gemini/antigravity/brain/c611579a-d164-4fdc-a460-b023fba73c33/.system_generated/tasks/task-2066.log`
Used tool: manage_task
Used tool: manage_task
Ran command: `grep -rnwi "GollekInferenceProvider" .`
Ran command: `cat /Users/bhangun/.gemini/antigravity/brain/c611579a-d164-4fdc-a460-b023fba73c33/.system_generated/tasks/task-2074.log`
Ran command: `cat src/main/resources/META-INF/services/tech.kayys.andalus.inference.InferenceProvider`
Viewed GrpcGollekStrategy.java:1-50
Viewed GollekInferenceProvider.java:50-100
Ran command: `git log -p -1 src/main/java/tech/kayys/andalus/provider/gollek/GollekInferenceProvider.java`

That is an excellent architectural question! 

You noticed that `GollekInferenceProvider` hardcodes delegating to the `gollek run` CLI subprocess instead of utilizing the `GrpcGollekStrategy` that exists elsewhere in the codebase. 

There are a few key reasons why `AlhambraEngine` currently defaults to the `gollek run` CLI approach instead of the gRPC API:

### 1. Zero-Configuration Local Setup
The primary reason is that calling the `gollek run` CLI is entirely stateless. If `AlhambraEngine` uses gRPC, it requires a separate `gollek server` daemon to be continually running in the background on a specific port (like `localhost:9000`). 
By using `gollek run`, the Java backend can completely manage the lifecycle of the LLM. It guarantees that if the backend is running and the `gollek` binary is in the `PATH`, inference will work out-of-the-box without requiring the user to manually launch and manage a separate background server process.

### 2. Differing SPI Abstraction Layers
If you look at the Java code, you'll see two different provider interfaces:
- `tech.kayys.andalus.provider.Provider` (which `GollekProvider` and `GrpcGollekStrategy` implement)
- `tech.kayys.andalus.inference.InferenceProvider` (which `GollekInferenceProvider` implements)

`AlhambraEngine` (specifically `AbstractAgentExecutionStrategy`) relies exclusively on the `InferenceProvider` SPI. Currently, `GollekInferenceProvider` is the only registered SPI implementation for this, and it was written specifically as a direct CLI wrapper to ensure maximum portability on macOS (e.g., executing GGUF/Metal directly). The `GrpcGollekStrategy` belongs to the other abstraction layer and isn't currently wired into the `AlhambraEngine` loop.

### 3. The Trade-off (The Memory Issue)
As you correctly experienced, the massive downside to the CLI `gollek run` approach is **memory thrashing and latency**. 
Because it's a CLI tool, the 8GB+ model must be loaded into macOS Unified Memory every single time the agent needs to think, and unloaded immediately after. In a multi-step ReAct loop (where the agent executes 5 tools in a row), this causes extreme memory pressure. 

A gRPC server approach would solve this entirely, as the model would stay persistently loaded in VRAM, making tool loops lightning fast and eliminating memory spikes. If `gollek` supports a stable gRPC server mode, wiring `GrpcGollekStrategy` into `AlhambraEngine` would be the best permanent upgrade for the architecture!



## 📜 License
Part of the **Andalus Platform** repository. Licensed under the Apache License 2.0.
