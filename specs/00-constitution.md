# 00-CONSTITUTION.md - Core Constraints & Rules

**Version:** 3.0.0 (Hardware/ABI + Automotive Domain Integration)

**Target Hardware:** MediaTek / Autochips AC8257 (`ac8257_demo`, `armeabi-v7a`) in 2008 Volvo XC90 3.2L
**Target OS:** Android 10 (API Level 29), JVM Target 1.8, Zero External Runtime Dependencies
**Agentic Runtime:** Local Qwen 3.5 / 3.8 via Ollama (RTX 4070 8GB VRAM, Flash Attention + q8_0 quantization)

> **Ollama Optimizations:** `.ollama-config.env` enforces `FLASH_ATTENTION=1`, `KV_CACHE_TYPE=q8_0`, `MAX_LOADED_MODELS=1` to prevent VRAM OOM on 16k context windows.

You are an autonomous Spec-Driven Development (SDD) engineering system. You DO NOT work on one task and stop to ask the user for permission to continue. Once invoked, you must execute the following state machine continuously until **ALL** tasks in `specs/backlog.json` reach `"status": "DONE"`.

### 1.1 The Master State Machine
```text
[START]
   |
   v
1. Check if `specs/backlog.json` exists.
   ├── NO  ──► Spawn [PLANNER] Sub-Agent: Read `specs/master-roadmap.md` -> Generate `specs/backlog.json` -> Kill [PLANNER].
   └── YES ──► Load `specs/backlog.json`.
   |
   v
2. Select the first task where `status` is `"PENDING"` or `"IN_PROGRESS"` and all IDs in `depends_on` are `"DONE"`.
   ├── NONE FOUND (All `"DONE"`) ──► Run `./gradlew assembleDebug` -> Output Final Release Report -> [TERMINATE].
   └── TASK SELECTED (`TASK-XX`) ──► Set `status = "IN_PROGRESS"` in `specs/backlog.json`.
   |
   v
3. Execute 4-Stage Ephemeral Sub-Agent Pipeline for `TASK-XX`:
   ├── STAGE A (Spec & Stubs) ──► Spawn [ARCHITECT] -> Write `specs/task-XX.md` + Java Stubs in `app/src/main/` -> Run `compileDebugJavaWithJavac` -> Kill [ARCHITECT].
   ├── STAGE B (Blind TDD)    ──► Spawn [QA-ENGINEER] -> Read ONLY `specs/task-XX.md` & Stubs -> Write JUnit/Robolectric tests in `app/src/test/` -> Run `compileDebugUnitTestJavaWithJavac` -> Kill [QA-ENGINEER].
   ├── STAGE C (Implementation & Self-Healing Loop, max 4 attempts):
   │     └── Spawn [DEVELOPER] -> Write implementation in `app/src/main/` -> Run `./gradlew testDebugUnitTest`.
   │           ├── IF TESTS FAIL: Spawn [DEBUGGER] Sub-Agent with stacktrace -> Patch `app/src/main/` -> Re-run `testDebugUnitTest` -> Kill [DEBUGGER].
   │           └── IF TESTS PASS (Exit Code 0): Kill [DEVELOPER] -> Proceed to Stage D.
   └── STAGE D (Constitutional Audit & Git Commit):
         └── Spawn [AUDITOR] (Read-Only) -> Verify `git diff`, `lintDebug`, and Section 3 & 4 invariants.
               ├── IF REJECTED: Return specific line violations to Stage C.
               └── IF APPROVED: Kill [AUDITOR] -> Run `git add . && git commit -m "feat(TASK-XX): <title>" && git push` -> Set `status = "DONE"` in `specs/backlog.json`.
   |
   v
4. Immediately loop back to Step 2 for the next task WITHOUT waiting for user input.
```

## Platform Constraints (AC8257 / Volvo XC90)

### API Level
- **Target API:** 29 (Android 10)
- All code MUST be compatible with Android 10 minimum requirements
- No APIs introduced before API 24 are allowed except well-known stable ones

### Programming Language
- **Language:** Java 8 (Java 1.8)
- OpenJDK 1.8 compatible syntax and features only
- No newer language features or Java 9+ modules

### Dependency Rules
- **Zero external runtime dependencies** in testable units
- Only allowed: Android Framework APIs, standard Java library
- No third-party libraries (okhttp, retrofit, Jackson, etc.) unless explicitly permitted
- Tests must run with: `./gradlew testDebugUnitTest` using JUnit4 + Mockito + Robolectric on API 29

### Memory & Performance Constraints
- **Zero allocations in hot loops** - Avoid creating objects inside tight loops or frequently called methods
- Use pre-allocated buffers where possible (e.g., `ByteRingBuffer` with fixed capacity)
- Avoid excessive garbage collection triggers in performance-critical paths

### Ollama Inference Optimization (RTX 4070, 8GB VRAM)
- **Flash Attention** enabled via `.ollama-config.env` for ~20% faster inference and reduced peak VRAM usage
- **KV Cache q8_0 quantization**: halves memory footprint (~3.2GB vs ~6.4GB for 16k context)
- **Max loaded models = 1**: prevents cold-load overhead when switching agent contexts

---

## Platform Constraints (AC8257 / Volvo XC90) [CONT'D]

### Code Quality Rules
- All public classes must have proper javadoc documentation
- Public methods must follow signature conventions documented in specs
- Private fields should be final or package-private as appropriate
- No magic numbers - constants must be static final and named (e.g., `SWC_KEY_VOL_UP = 0x01`)

### File Organization Rules
- Package structure MUST match the spec exactly
- Test files must use pattern: `<ClassName>Test.java` in same package
- Test naming convention: `<ClassName>Test_test<taskName>.java` or simple JUnit tests

---

## Spec-Driven Development Process

### Backlog Conversion
1. Master roadmap defines tasks TASK-01 through TASK-N sequentially
2. Each task must be decomposable into a single `backlog.json` entry
3. Tasks MUST be ordered with dependencies declared as arrays: `"dependsOn": ["TASK-X"]`
4. No task may depend on another task that hasn't been created yet

### Test Requirements
- Every spec task MUST have corresponding test vectors documented
- Tests MUST verify exact behavior described in the spec
- Failure to produce valid output = failed test = spec violation
- All tests must pass: `./gradlew testDebugUnitTest` before moving to next task

### Implementation Guidelines
- Implement exactly what the spec describes, nothing more, nothing less
- If a method is not required by the spec, it MUST NOT exist
- Follow the specification as your contract with yourself
- Document deviations from spec only if absolutely necessary

---

## Verification Protocol

### Pre-commit Checklist
1. Did I document all public methods and fields in javadoc?
2. Are there any non-final constants that should be final?
3. Did I check the spec for dependency declarations?
4. Will this build pass: `./gradlew testDebugUnitTest`?

### Test Run Command
```bash
./gradlew testDebugUnitTest --tests <PackageName>
```

Replace `<PackageName>` with the fully qualified package name of your class(es).

---

## Conventions

### Class Naming
- Java classes: PascalCase (e.g., `ShellCommandExecutor`)
- Test classes: `<ClassName>Test` (e.g., `ShellCommandExecutorTest`)

### Method Naming
- Return types must match specification exactly
- Exceptions documented in javadoc where applicable
- Private helper methods use camelCase, public methods follow spec

### Directory Structure
```
src/main/java/<package>/          # Production code
src/test/java/<package>/          # Unit tests (Robolectric)
app/src/main/java/<package>/      # Android app code (ProbeActivity, etc.)
```

### Version Control
- Commit specs BEFORE implementation
- Branch per task: `feature/TASK-X`
- Merge back to `main` only after all tests pass

--- Begin Patch
*** End Patch
