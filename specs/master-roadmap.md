# MASTER ROADMAP: Custom Automotive OS & Diagnostic Probe (AC8257 / Volvo XC90)

## Instructions for the Planner Sub-Agent
Decompose this roadmap into `specs/backlog.json` containing exactly 10 sequential tasks (`TASK-01` through `TASK-10`).
Each task MUST be small, self-contained, and independently verifiable via `./gradlew testDebugUnitTest` (JUnit4 + Mockito + Robolectric on API 29).
Enforce all rules from `specs/00-constitution.md` (API 29, Java 8, zero external runtime dependencies, no databases, zero allocations in hot loops).

---

## PHASE 1: Head Unit Reconnaissance & Diagnostic Probe (`com.volvo.hu.probe`)

### TASK-01: ShellCommandExecutor & Safe Process Runner
- **Target Package:** `com.volvo.hu.probe.shell`
- **Objective:** Implement a thread-safe shell execution utility to query low-level Android 10 system state without blocking the main thread or hanging on deadlocks.
- **Required Classes & Signatures:**
  - `public class ShellResult`:
    - `public final int exitCode;`
    - `public final String stdout;`
    - `public final String stderr;`
    - `public final boolean timedOut;`
    - `public boolean isSuccess()` (returns `exitCode == 0 && !timedOut`)
  - `public class ShellCommandExecutor`:
    - `public ShellResult execute(String[] command, long timeoutMs)`
    - Must validate input (`IllegalArgumentException` on null/empty command or `timeoutMs <= 0`).
    - Must capture both `stdout` and `stderr` bounded to 256 KB max to prevent OOM.
    - If execution exceeds `timeoutMs`, forcibly destroy the process (`process.destroyForcibly()`) and return `timedOut = true`.
- **QA Test Vectors:**
  - Verify normal command execution (`echo hello`) returns `exitCode == 0` and `"hello"`.
  - Verify timeout handling when a command sleeps longer than `timeoutMs`.
  - Verify null/empty command array throws `IllegalArgumentException`.

### TASK-02: Hardware, Serial Ports & System Properties Collector
- **Depends On:** `["TASK-01"]`
- **Target Package:** `com.volvo.hu.probe.collectors`
- **Objective:** Parse Android system properties (`getprop`) and scan `/dev/` device nodes to identify MCU/CAN UART ports (`/dev/ttyMT*`, `/dev/ttyS*`), video capture nodes (`/dev/video*`, `/dev/ashmem`), and GPS nodes (`/dev/stpgps`, `/dev/gps`).
- **Required Classes & Signatures:**
  - `public class HardwareProbeCollector`:
    - `public HardwareProbeCollector(ShellCommandExecutor executor)`
    - `public Map<String, String> parseGetpropOutput(String rawOutput)`
      - Parses lines matching `[key]: [value]` format, ignoring malformed lines.
    - `public Map<String, String> filterAutomotiveProperties(Map<String, String> allProps)`
      - Filters keys containing any of: `"jancar"`, `"baony"`, `"canbus"`, `"atc"`, `"mtk"`, `"mcu"`, `"serial"`, `"audio"`, `"camera"`, `"gps"`, `"ro.product"`, `"persist.sys"`.
    - `public List<String> scanDeviceNodes(File devDirectory)`
      - Lists device files matching prefixes `ttyMT`, `ttyS`, `ttyUSB`, `video`, `stp`, `gps`, `ashmem`, returning formatted strings `"name|readable|writable"`.
- **QA Test Vectors:**
  - Feed multi-line `getprop` mock output with `[ro.board.platform]: [ac8257]` and `[persist.sys.canbus]: [volvo]` and verify exact parsing and filtering.
  - Test `scanDeviceNodes` against a temporary directory (`TempFolder`) containing mock device files.

### TASK-03: Audio Subsystem & GNSS/NMEA Auditor
- **Depends On:** `["TASK-01"]`
- **Target Package:** `com.volvo.hu.probe.auditors`
- **Objective:** Audit all Android `AudioManager` stream levels (`STREAM_MUSIC`, `STREAM_NOTIFICATION`, `STREAM_VOICE_CALL`, `STREAM_SYSTEM`, `STREAM_ALARM`) and `LocationManager` GNSS provider states.
- **Required Classes & Signatures:**
  - `public class SubsystemAuditor`:
    - `public JSONObject auditAudioStreams(AudioManager audioManager)`
      - Records current volume and max volume for streams: `STREAM_MUSIC`, `STREAM_NOTIFICATION`, `STREAM_ALARM`, `STREAM_VOICE_CALL`, `STREAM_SYSTEM`.
    - `public JSONObject auditLocationProviders(LocationManager locationManager)`
      - Lists all providers (`getAllProviders()`), whether `gps` and `network` providers are enabled, and captures a ring buffer of up to 20 raw NMEA sentences via `recordNmeaSentence(long timestamp, String nmea)`.
- **QA Test Vectors:**
  - Mock `AudioManager` and `LocationManager` using Mockito; verify JSON structure and exact stream volume values.
  - Verify `recordNmeaSentence` keeps only the latest 20 NMEA sentences in FIFO order.

### TASK-04: Interactive 30-Second CAN, KeyEvent & Broadcast Sniffer
- **Depends On:** `["TASK-01"]`
- **Target Package:** `com.volvo.hu.probe.sniffer`
- **Objective:** Capture hardware Steering Wheel Control (SWC) key events, volume change broadcasts, and `com.jancar.*` / `com.baony.*` system broadcasts during a live capture session.
- **Required Classes & Signatures:**
  - `public class InteractiveEventSniffer`:
    - `public void startSession(long durationMs)`
    - `public void stopSession()`
    - `public boolean isRecording()`
    - `public void onKeyEventCaptured(int keyCode, int scanCode, int action, int deviceId)`
    - `public void onBroadcastCaptured(String action, Map<String, String> extras)`
    - `public JSONArray getCapturedEventsJson()`
      - Returns chronological JSON array of all events recorded while `isRecording() == true` (bounded to max 500 events). Events arriving when `isRecording() == false` must be ignored.
- **QA Test Vectors:**
  - Verify events are recorded only after `startSession` and ignored after `stopSession`.
  - Verify capacity bound (500 events max) and accurate JSON serialization of `keyCode`, `scanCode`, and Intent extras.

### TASK-05: Diagnostic Report Exporter & Probe MainActivity
- **Depends On:** `["TASK-02", "TASK-03", "TASK-04"]`
- **Target Package:** `com.volvo.hu.probe`
- **Objective:** Aggregate all collected data into a single formatted JSON report file (`/sdcard/hu_probe_report.json` and app external files dir) and provide a dark-themed Android `Activity` to trigger the scan on the head unit.
- **Required Classes & Signatures:**
  - `public class ProbeReportExporter`:
    - `public String buildFullReportJson(Map<String, String> autoProps, List<String> devNodes, JSONObject audioJson, JSONObject gpsJson, JSONArray snifferEvents, String logcatTail)`
    - `public boolean writeReportToFile(File targetFile, String jsonContent)`
  - `public class ProbeActivity extends Activity`:
    - Programmatic UI layout (no complex XML required) with a dark background, status `TextView`, `"START 30s SCAN"` button, and `"SAVE REPORT"` button.
- **QA Test Vectors:**
  - Verify `buildFullReportJson` produces valid, parseable JSON containing all 6 top-level sections.
  - Verify `writeReportToFile` writes UTF-8 content to disk and returns `true`.

---

## PHASE 2: Core Automotive OS Services (Platform AC8257 / Volvo XC90)

### TASK-06: Native UART JNI Wrapper (`SerialPort`) & Zero-Allocation RingBuffer
- **Depends On:** `["TASK-05"]`
- **Target Packages:** `com.baony.sdk.canbus` and `com.volvo.hu.canbus.io`
- **Objective:** Implement the exact JNI bridge for `libSerialPort_jni.so` and a lock-free/synchronized pre-allocated circular byte buffer (`byte[4096]`) for reading UART bytes without triggering garbage collection.
- **Required Classes & Signatures:**
  - `package com.baony.sdk.canbus; public class SerialPort`:
    - `private FileDescriptor mFd;`
    - `public native static FileDescriptor open(String path, int baudrate, int flags);`
    - `public native void close();`
  - `package com.volvo.hu.canbus.io; public class ByteRingBuffer`:
    - `public ByteRingBuffer(int capacity)` (default 4096)
    - `public synchronized int write(byte[] src, int offset, int length)`
    - `public synchronized int readByte()` (returns `0..255` or `-1` if empty)
    - `public synchronized int peek(int index)`
    - `public synchronized void skip(int count)`
    - `public synchronized int available()`
    - `public synchronized void clear()`
- **QA Test Vectors:**
  - Test `ByteRingBuffer` wrap-around behavior (writing and reading past array boundary `capacity * 3` times).
  - Test buffer overflow handling, `peek()`, `skip()`, and `clear()`.

### TASK-07: In-Memory VehicleState & Volvo XC90 CAN Frame Parser
- **Depends On:** `["TASK-06"]`
- **Target Package:** `com.volvo.hu.canbus.parser`
- **Objective:** Parse incoming UART byte frames from the Volvo CAN-box (`[HEADER 0x2E] [CMD_TYPE] [LENGTH] [DATA... ] [CHECKSUM]`, where `CHECKSUM = (sum(CMD_TYPE, LENGTH, DATA...) ^ 0xFF) & 0xFF`) and update an in-memory `VehicleState` singleton.
- **Required Classes & Signatures:**
  - `public class VehicleState`:
    - Volatile fields: `boolean reverseGear`, `int steeringWheelAngle` (`-540..+540`), `int[] rearParkSensors` (length 4, values `0..255`), `int[] frontParkSensors` (length 4), `int doorMask` (bitmask for FL, FR, RL, RR, Hood, Trunk), `int lastSwcKeyCode`, `int outdoorTempHalfCelsius`.
    -Getters and package-private setters; `reset()` method.
  - `public class VolvoCanFrameParser`:
    - `public static final byte HEADER_BYTE = 0x2E;`
    - `public static byte calculateChecksum(byte cmdType, byte length, byte[] payload, int offset)`
    - `public int processIncomingBytes(ByteRingBuffer buffer, VehicleState state)`
      - Scans `buffer` for `0x2E`, validates length and checksum, updates `VehicleState` for SWC keys (`cmdType = 0x20`), Rear Radar (`0x22`), Front Radar (`0x23`), Doors/Reverse status (`0x24`), Steering Angle (`0x26`), and returns the number of valid frames parsed. Skips corrupted bytes cleanly.
- **QA Test Vectors:**
  - Test valid Volvo frames for SWC Vol+/Vol-, Reverse Gear ON/OFF, 4-zone radar distances, and negative/positive steering angles.
  - Fuzz test with garbage bytes before/between valid frames and corrupted checksums; verify parser recovers and extracts all valid frames without throwing exceptions.

### TASK-08: SWC Volume Isolation, Software Audio Ducking & ACC Sleep Media Controller
- **Depends On:** `["TASK-07"]`
- **Target Package:** `com.volvo.hu.audio`
- **Objective:** Ensure Steering Wheel volume buttons (`VOL_UP = 0x01`, `VOL_DOWN = 0x02`) NEVER change Android's internal `AudioManager` volume (since the stock Volvo amplifier handles volume directly), while supporting software audio ducking during navigation voice prompts and auto-pause/resume across ACC sleep cycles.
- **Required Classes & Signatures:**
  - `public class SwcAudioController`:
    - `public static final int SWC_KEY_VOL_UP = 0x01;`
    - `public static final int SWC_KEY_VOL_DOWN = 0x02;`
    - `public static final int SWC_KEY_NEXT = 0x03;`
    - `public static final int SWC_KEY_PREV = 0x04;`
    - `public static final int SWC_KEY_MUTE = 0x05;`
    - `public SwcAudioController(AudioManager audioManager, boolean stockAmpPassThrough)`
    - `public boolean handleSwcKey(int swcKeyCode, int action)`
      - When `stockAmpPassThrough == true`, `SWC_KEY_VOL_UP` and `SWC_KEY_VOL_DOWN` MUST NOT call `audioManager.adjustStreamVolume(...)` or `setStreamVolume(...)`.
      - For `SWC_KEY_NEXT` and `SWC_KEY_PREV`, dispatches `KeyEvent.KEYCODE_MEDIA_NEXT` / `KEYCODE_MEDIA_PREVIOUS` via `audioManager.dispatchMediaKeyEvent(...)`.
    - `public void onNavigationPromptStateChanged(boolean promptActive)`
      - Tracks ducking state (`isDucked()`) and calculates software multiplier (`0.4f` when active, `1.0f` when inactive) without altering hardware CAN volume.
    - `public void onAccPowerStateChanged(boolean accOn)`
      - On `accOn == false`: if music was active, dispatches `KEYCODE_MEDIA_PAUSE` and remembers state (`shouldResumeOnWake()`).
      - On `accOn == true`: if `shouldResumeOnWake() == true`, dispatches `KEYCODE_MEDIA_PLAY`.
- **QA Test Vectors:**
  - Verify `Mockito.verify(audioManager, Mockito.never()).adjustStreamVolume(anyInt(), anyInt(), anyInt())` when `SWC_KEY_VOL_UP` and `SWC_KEY_VOL_DOWN` are handled in `stockAmpPassThrough` mode.
  - Verify `SWC_KEY_NEXT` dispatches `KEYCODE_MEDIA_NEXT`.
  - Verify `onAccPowerStateChanged(false)` followed by `onAccPowerStateChanged(true)` pauses and resumes media playback.

### TASK-09: GNSS / NMEA Health Monitor & Fast-Lock Configurator
- **Depends On:** `["TASK-03"]`
- **Target Package:** `com.volvo.hu.gps`
- **Objective:** Parse NMEA `$GPGGA` and `$GPRMC` sentences to monitor fix quality, satellite count, and HDOP for the launcher status bar, and generate an optimized European `gps.conf` configuration.
- **Required Classes & Signatures:**
  - `public class GnssHealthMonitor`:
    - `public boolean parseNmeaSentence(String nmea)`
    - `public boolean hasValidFix()`
    - `public int getSatellitesInUse()`
    - `public float getHdop()`
    - `public double getLatitude()`
    - `public double getLongitude()`
    - `public static boolean verifyNmeaChecksum(String nmea)`
    - `public static String generateEuropeanGpsConf()` (returns config with `NTP_SERVER=europe.pool.ntp.org`, `SUPL_HOST=supl.google.com`, `SUPL_PORT=7275`).
- **QA Test Vectors:**
  - Test `verifyNmeaChecksum` with valid and corrupted `$GPGGA` strings.
  - Test parsing of `$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47` and verify `satellitesInUse == 8`, `hdop == 0.9f`, `hasValidFix() == true`.

### TASK-10: Reverse Camera (CVBS) & Park Assist Overlay Controller
- **Depends On:** `["TASK-07", "TASK-08"]`
- **Target Package:** `com.volvo.hu.overlay`
- **Objective:** Manage the state and normalized radar/trajectory geometry for the Volvo XC90 reverse camera overlay whenever `VehicleState.isReverseGear()` or front/rear park sensors become active.
- **Required Classes & Signatures:**
  - `public class ReverseOverlayController`:
    - `public boolean shouldShowOverlay(VehicleState state)`
      - Returns `true` if `state.isReverseGear()` is true OR any sensor in `rearParkSensors` / `frontParkSensors` is `> 0` and `< 120`.
    - `public float calculateNormalizedTrajectoryCurve(int steeringWheelAngle)`
      - Clamps angle to `[-540, 540]` and returns normalized curvature in `[-1.0f, +1.0f]`.
    - `public int mapSensorDistanceToHazardLevel(int rawValue)`
      - Maps raw CAN radar distance to hazard levels: `0` (Safe/Inactive), `1` (Green), `2` (Yellow), `3` (Red/Critical).
- **QA Test Vectors:**
  - Verify `shouldShowOverlay` triggers on reverse gear and on close front obstacle even in forward gear.
  - Verify `calculateNormalizedTrajectoryCurve` clamping at `-600` (`-1.0f`), `0` (`0.0f`), and `+270` (`+0.5f`).
  - Verify hazard level mapping across boundary values.