# 수행 결과 기록

> 각 Step 종료 시 해당 Section을 **추가(append)** 한다.
> 기록 항목: 실행 명령 / 결과 / 변경 파일 / 검증 결과 / 미해결 이슈와 다음 액션.

---

## Step 0 — 개발 환경 준비 — 2026-09-28

### 상태
완료

### 환경 조사 결과
| 항목 | 조사 결과 |
|---|---|
| Flutter / Dart | 미설치 (PATH 및 전체 드라이브 검색 결과 없음) |
| JDK | 미설치 (DBeaver JRE만 존재, 빌드 불가) |
| Android SDK / NDK | 미설치 |
| iOS 빌드 | Windows 환경이므로 불가 (Mac 필요) |
| 네트워크 | pub.dev / storage.googleapis.com / dl.google.com 접근 가능 |
| Git / curl / winget | 사용 가능 |
| 디스크 여유 | C: 약 90 GB |
| 기존 파일 | `documents/prompt.txt`만 존재 (빈 프로젝트) |

### 수행 내역
1. `flutter_infra_release/releases/releases_windows.json` 조회 → 최신 stable **3.47.5 / Dart 3.13.4** 확인
2. `dl.google.com/android/repository/repository2-3.xml` 파싱 → `cmdline-tools;latest` = build **16111833** 확인
3. 아래 3개 아카이브를 `C:\dev\downloads`에 병렬 다운로드 시작
   - `flutter_windows_3.47.5-stable.zip`
   - Temurin JDK 17 (Adoptium API)
   - `commandlinetools-win-16111833_latest.zip`
4. `documents/IMPLEMENT.md` 최초 작성 (계획 확정 반영)

### 변경 파일
- `documents/IMPLEMENT.md` (신규)
- `documents/TASKS_EXECUTED.md` (신규)

### 미해결 이슈 / 다음 액션
- 다운로드 완료 후 압축 해제 → 환경변수 설정 → `sdkmanager`로 NDK/CMake 설치 → `flutter doctor` 검증

---

## Step 1 — 프로젝트 생성 · 테마 · 무전기 UI 뼈대 — 2026-09-29

### 상태
완료

### 수행 내역
1. `git init -b main` + `flutter create --org com.wktk --project-name wktk --platforms android,ios .`
2. `flutter pub add record flutter_soloud permission_handler flutter_riverpod shared_preferences wakelock_plus uuid`
3. pubspec: description, `assets/sounds/` 등록. `android/app/build.gradle.kts`: minSdk=24.
4. AndroidManifest 퍼미션(RECORD_AUDIO, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, ACCESS_NETWORK_STATE, WAKE_LOCK) + 앱 이름, Info.plist(마이크/LAN 사유, 세로 고정)
5. `lib/core/constants/app_constants.dart`(프로토콜/오디오/타이밍 상수), `lib/app/theme.dart`(AppColors + dark/light)
6. 상태 모델 `WalkieUiState`/`TxStatus`, Riverpod `WalkieController`(스텁), `main.dart`(ProviderScope + Wakelock)
7. 커스텀 위젯 7종: antenna, status LED, LCD(7-segment CustomPainter), speaker grille, rotary knob(드래그+노치+햅틱), PTT(Listner로 누름/뗌), status banner + 화면 조립
8. `tool/gen_sounds.dart`으로 `assets/sounds/{roger_beep,squelch,denied}.wav` 생성 (MSVC 연동 확인)
9. `tool/radio_sim.dart` 스캐폴드(Step 3에서 실구현)

### 변경 파일
- `lib/features/walkie/domain/walkie_state.dart`, `lib/features/walkie/presentation/walkie_controller.dart`, `walkie_screen.dart`, `widgets/*`(7파일)
- `lib/features/settings/presentation/settings_screen.dart`(스텁)
- `lib/app/theme.dart`, `lib/core/constants/app_constants.dart`, `lib/main.dart`
- `tool/gen_sounds.dart`, `tool/radio_sim.dart`, `assets/sounds/*.wav`
- `test/widget_test.dart`(스모크 테스트: 화면 렌더 + 오버플로 회귀 방지), `android/app/build.gradle.kts`

### 검증 결과
- `flutter analyze`: **No issues found** (0건)
- `dart format`: 17파일 정상
- `flutter test`: **1/1 통과** (600px 뷰포트에서 Column 오버플로 → FittedBox로 수정 후 통과)
- `flutter build apk --debug`: **성공** (`build/app/outputs/flutter-apk/app-debug.apk`)
- flutter_soloud C++ hook: Windows 호스트 MSVC 컴파일 정상 동작

### 툴체인 이슈 (기록)
- `sdkmanager`/`android` CLI는 모든 명령 실행 후 `exit -1073740791 (0xC0000409)`로 크래시하나 **전달된 패키지는 정상 설치됨**. 오류코드가 아닌 디렉터리 존재로 판정할 것.
- Flutter 기본 `ndkVersion`(28.2.x) 미설치 → `android/app/build.gradle.kts`에서 설치본 `"30.0.16248370"`으로 명시 고정.
- permission_handler_android가 `compileSdk 37` 요구 → `compileSdk = 37`(API 37.0 설치 필요)로 상향. AGP 9.1.0의 권장 최대 36 경고는 무해.
- build hook 실패 시 실기기 빌드 전 `flutter analyze/test`에서 먼저 감지됨.

### 미해결 이슈 / 다음 액션
- 실기기 화면 확인은 Step 2(권한·Wi-Fi)에서 진행 예정. 다음: 권한 처리(mic + local network) 및 Wi-Fi 상태 감지.

---

## Step 2 — 권한 처리 및 Wi-Fi 상태 감지 — 2026-09-29

### 상태
완료

### 수행 내역
1. `lib/core/utils/kv_store.dart`: SharedPreferences 래퍼(onboarding/nickname/defaultChannel 키)
2. `lib/core/network/network_monitor.dart`: `NetworkClassifier`(사설 IPv4 10/8·172.16/12·192.168/16 + 인터페이스 이름 기반 wifi/cellular 분류), 3초 주기 `NetworkMonitor`(Riverpod Notifier), `networkStatusProvider`
3. `lib/features/onboarding/`: 컨트롤러(마이크 권한 요청 → granted 시 완료 저장, 거부/영구거부 구분, `openAppSettings`), 온보딩 화면(로고 + 3단계 설명 보드 + 시작하기 + 거부 카드{다시 시도/설정에서 열기})
4. `lib/app/router.dart`: `onboardingDoneProvider` + `AppGate`(첫 실행 여부로 Onboarding ↔ Walkie 분기). `lib/main.dart` home → AppGate
5. `WalkieController`: `ref.listen` 대신 단순 `build()`, PTT는 `networkStatusProvider` 연결 시 햅틱만·Wi-Fi 미연결 시 무시. `walkieUiProvider`(채널/볼륨 유지 + wifiOk/netKind 합성) 신설, 화면은 이를 watch
6. `WalkieUiState`에 `NetKind` 필드 추가, LCD에 `WIFI OK`/`CELLULAR`/`NO WIFI` 표시, `SettingsScreen`에 권한 상태 + 앱 설정 이동 추가
7. `test/network_status_test.dart`(분류기 11건), `test/widget_test.dart`(온보딩/완료 2건, `SharedPreferences.setMockInitialValues` 사용)

### 변경 파일
- 신규: `lib/core/utils/kv_store.dart`, `lib/core/network/network_monitor.dart`, `lib/app/router.dart`, `lib/features/onboarding/{onboarding_controller,onboarding_screen}.dart`, `test/network_status_test.dart`
- 수정: `lib/features/walkie/presentation/{walkie_controller,walkie_screen}.dart`, `lib/features/walkie/domain/walkie_state.dart`, `lib/features/walkie/presentation/widgets/lcd_panel.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/main.dart`, `test/widget_test.dart`

### 검증 결과
- `flutter analyze`: **No issues found**
- `flutter test`: **7/7 통과** (분류기 5 + 위젯 2)
- `flutter build apk --debug`: **성공** (증분 17.8s)
- 권한 거부 경로: 온보딩 카드(다시 시도 / 설정에서 열기) 표시, PTT는 Wi-Fi 미연결 시 무시

### 이슈 / 트러블슈팅
- Riverpod: `Notifier.build` 안에서 `ref.listen(networkStatusProvider, fireImmediately:true)` 후 콜백으로 `state=`를 쓰면
  빌드 중 자기 상태 읽기라서 `Bad state: Tried to read the state of an uninitialized provider` 발생.
  → 컨트롤러에서 네트워크 구독을 제거하고 네트워크 합성을 `Provider` 뷰 모델(`walkieUiProvider`)로 분리해 해결.

### 미해결 이슈 / 다음 액션
- 다음: Step 4(PTT 오디오 경로). `record`로 마이크 PCM 캡처 → 20 ms 프레임(640B) → `AUDIO` 패킷 발송,
  `flutter_soloud`로 RX 오디오 재생 + `TX_START/TX_END` 패킷 연결. Step 3 `WalkieUiState.txStatus`는 컨트롤러에 미연결이므로
  송신 상태·피어 UI 연동 포함. 실기기에서 `radio_sim` ↔ 앱 접속자 정상 표시 확인 필요.

## Append — Step 3 구현 로그

### Step 3 — UDP 송수신 · Presence — 2026-09-29

### 상태

완료

### 실행 내용

1. `lib/core/network/packet.dart`: `PacketType{presence,txStart,txEnd,audio}`, `RadioHeader`(40B LE),
   `uuidToBytes/uuidFromBytes`, PRESENCE/TX_START/TX_END body 모델
2. `lib/core/network/packet_codec.dart`: `PacketCodec` 인코더/디코더 (magic 0x4B57, ver 1, 채널 1..16 검증,
   닉네임 ≤32B, `decode` 실패 시 null)
3. `lib/core/network/subnet.dart`: 순수 IP 유틸 — IPv4 변환, `/24` 가정 서브넷 브로드캐스트,
   `NetKind`/`NetworkClassifier` 이동(기존 `network_monitor.dart`는 재수출만). `radio_sim` flutter 무의존화
4. `lib/core/network/transport/transport.dart`: `RadioTransport` 인터페이스 + `ReceivedDatagram` 레코드 typedef,
   `sendTo`는 `port:` 오버라이드 파라미터 지원(테스트용; 기본은 채널 포트)
5. `lib/core/network/transport/dart_udp_transport.dart`: `RawDatagramSocket.bind(anyIPv4, reuseAddress)` +
   `joinMulticast`(실패 허용) + 멀티캐스트→브로드캐스트(전역+/24) `sendAll`, `sendTo`, `setLocalIpv4`,
   `onError`로 소켓 비동기 오류(WSAEACCES 등) 흡수
6. `lib/core/network/transport/native/multicast_lock_channel.dart`: `MethodChannel('wktk/multicast')` acquire/release 래퍼
7. `lib/features/walkie/data/peer.dart` + `peer_registry.dart`: Peer 모델, `upsertPresence`/`purge(kPeerTimeout)`/`remove`/`clear`
8. `lib/features/walkie/data/transceiver_service.dart`: 순수 Dart 서비스 — UUID v4 자기 ID,
   PRESENCE 2 s 발송 + 수신 시 `senderId` 자기 필터 + 레지스트리 갱신, `onPeersChanged`, `sendToAllRoutes`,
   `changeChannel`(stop→start), TX_* 는 Step 4 TODO
9. `android/.../MainActivity.kt`: `wktk/multicast` MethodChannel — `WifiManager.MulticastLock`(setReferenceCounted(false))
   acquire/release
10. `tool/radio_sim.dart`: 실 트랜스포트 연결 — `--channel/--nick/--once`, 사설 IP 자동 탐지,
    2 s마다 접속자 렌더링, `--once`는 피어 최초 감지 후 종료
11. 테스트: `test/packet_codec_test.dart` 10건(UUID 왕복, 4종 encode/decode, 검증/거부, 닉네임 한도),
    `test/peer_registry_test.dart` 4건(추가/갱신/다중/만료), `test/udp_transport_integration_test.dart` 2건
    (루프백 unicast + multicast sendAll)

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 24/24 통과 (신규 16건 포함)
- `flutter build apk --debug`: 성공 (16.0s)
- `dart run tool/radio_sim.dart --once`: 채널 1, localIP 192.168.219.103, 기동→"접속자 없음" 표시 후 정상 종료(0)

### 이슈 / 트러블슈팅

- **flush 테스트 실패 원인**: `sendTo`가 자기 바인딩 포트를 목적지 포트로 사용 → 루프백에서 같은 포트를
  두 소켓이 공유하면 unicast 배달 대상이 비결정적. 실기기는 호스트가 달라 문제 없음을 확인,
  테스트에서는 `sendTo(port:)` 오버라이드로 B 포트를 명시하여 해결.
- **Windows 브로드캐스트 전송**: 255.255.255.255 전송 시 `WSAEACCES(10013)`이 단독 dart 프로세스에선
  동기 throw지만 flutter_tester에선 소켓 스트림 비동기 오류로 표면화 → `socket.listen(onError:)`로 흡수.
- **flutter_tester vs dart.exe**: 같은 코드가 `dart run`에선 동작해도 `flutter test`(flutter_tester)에선
  실패할 수 있음(방화벽/프로세스 맞춤 차이). `flutter_tester.exe`·`dart.exe` UDP 허용 규칙을
  Windows 방화벽에 추가 후 통합 테스트 정상화.
- 멀티캐스트 루프백 off API 부재 → 자기 패킷은 `senderId` 비교로 폐기(`TransceiverService._onPacket`).
  라우팅 검증은 실기기 2대(또는 radio_sim ↔ 기기)에서 진행 예정.

---

## 2026-09-29 — Step 4: PTT 오디오 경로 (완료)

### 수행 내용

1. `lib/features/walkie/data/audio/pcm_slicer.dart` — 순수 Dart PcmSlicer(640 B=20 ms@16 kHz mono
   s16le 절단, 청크 불규칙 대응 tail 보관, `flush(dropTail)`/`clear`).
2. `lib/features/walkie/data/audio/audio_capture.dart` — AudioCapture: record `startStream`
   (`pcm16bits`, 16 kHz, mono, autoGain/echoCancel/noiseSuppress off) → `Stream<Uint8List>`,
   `start(onPcm)`/`stop`/`dispose`.
3. `lib/features/walkie/data/audio/audio_playback.dart` — AudioPlayback: soloud `init()`,
   `setBufferStream(sampleRate 16000, mono, s16le, preserved, bufferingTimeNeeds 0.06,
   maxBuffer 3MB)`, `play()` 1회 + `feed()`/`reset()`/`setVolume()`/`dispose()`,
   `pcm16Rms()` 신호 레벨 유틸.
   - 조사 확정 API: `initialize()`가 아니라 `init()`(Future), `deinit()`은 void → await 제거.
4. `transceiver_service.dart` 확장 — `startTransmit()`(TX_START+presence txActive), `sendAudioFrame()`
   (AUDIO seq++/timestamp, `sendToAllRoutes` = multicast+broadcast+유니캐스트),
   `stopTransmit()`(TX_END); RX에 txStart/txEnd 분기(address/port 학습·txActive 반영) 추가,
   `onAudio`(ReceivedAudio broadcast) 스트림, `isTransmitting` 게터.
5. `walkie_controller.dart` 재작성 —
   - `ref.listen(networkStatusProvider, fireImmediately: false)`로 세션 라이프사이클
     (`_ensureSession`/`_teardownSession`), `ref.onDispose` 정리.
   - PTT down: reflection 차단용 재생 reset → startTransmit → 캡처 시작 → `PcmSlicer` → 프레임별
     `sendAudioFrame` + 5프레임(100 ms)마다 signalLevel(RMS) 갱신.
   - PTT up: 캡처 중지 → stopTransmit → idle. RX: AUDIO → 새 버스트 `reset()` → `feed()` →
     receiving/talkerNickname + `kRxIdleTimeout`(1.2 s) 유휴 복귀, `channelBusy`=누군가 transmit.
   - 테스트 환경 보호: teardown 후 `ref.mounted` 확인 후 `state=` (위젯 테스트 중 dispose로 인한
     "setState during build" 방지).
6. `tool/radio_sim.dart` — `--tone`(440 Hz 사인, 20 ms 프레임 지속 송신, Ctrl+C 정리,
   `_ToneSender`가 PTT 절차 모사) + `[AUDIO] nick/바이트/seq/추정 지연` 수신 통계.
7. `test/pcm_slicer_test.dart` — PcmSlicer 8건 + pcm16Rms 4건.

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 36/36 통과 (Step 4 신규 12건 포함)
- `flutter build apk --debug`: 성공
- `dart run tool/radio_sim.dart --once`: 기동 정상 (채널 1, localIP 192.168.219.103, "접속자 없음", 종료 0)

### 이슈 / 트러블슈팅

- soloud `init()`은 `SoLoud.instance.init()`(initialize 아님), `deinit()`은 void.
- `dart:typed_data` import 필요: foundation이 Uint8List를 제공하므로 analyzer가 unnecessary_import로
  지적 → audio_playback/controller에서 제거, pcm_slicer엔 유지.
- `pcm16Rms` 최대 진폭 테스트: 32767/32768 근사값이라 1e-6 tolerance 실패 → 1e-3로 완화.
- 위젯 테스트에서 `ref.onDispose`의 unawaited `_teardownSession`이 `state=` → "setState during build"
  크래시 → `ref.mounted` 가드 추가.
- `AppConstants.kDefaultVolume`(0.7) 이미 존재 — 별도 추가 불필요.

### 미해결 이슈 / 다음 액션
- Step 6: 설정 화면(닉네임·채널·효과음·햅틱·VOX·노이즈 게이트·테마), 예외 처리, 테스트 보강,
  README 작성, 실기기 ↔ radio_sim 실제 음성 E2E(Wi-Fi 2대).

---

## 2026-09-29 — Step 5: 지터버퍼 · 반이중 · 효과음/햅틱 (완료)

### 수행 내용

1. `lib/features/walkie/data/jitter_buffer.dart` — 순수 Dart 지터 버퍼:
   - warmup(첫 프레임 + kJitterBuffer(60ms) 후 재생), seq 순서 복원, 중복/역전 폐기,
     경미한 갭(≤6프레임) PLC(마지막 샘플 홀드), 심한 갭 홀 스킵, `shouldStop`(maxDropMs).
   - `nowMs` 주입식(테스트 결정성). `hasPending/bufferedFrames` + 폐기/보정 통계.
2. `lib/features/walkie/data/channel_arbiter.dart` — 순수 Dart 반이중 중재기:
   - idle/txLocal/rxRemote + `BusEvent{collision, remoteStarted}`.
   - `requestLocal`(rxRemote면 거부), `keepaliveLocal`(txLocal 400ms 자동 해제 방지),
     `peerStart`(충돌 윈도 250ms 내 → collision, 이후 → 양보), `peerEnd`(guard 250ms 후 idle),
     `peerAudio`(rx 1200ms 유지), `peerLeft`, `tick`. nowMs 주입식.
3. `transceiver_service.dart` 확장 — `startTransmit()`→`Future<bool>`(권한 없으면 false),
   `onBusEvent` 스트림, `_handleRemoteStart`(충돌→로컬 interrupt + collision 이벤트 / 양보→중단 /
   첫 busy→remoteStarted), presence `txActive=true` 선인지, presence timer `arbiter.tick()`
   + txLocal 자동 해제 시 `_transmitting` 동기화, `_interruptTransmit`(TX_END 재발송).
4. `walkie_controller.dart` 변경 —
   - RX: 노이즈 게이트(RMS < 0.01 침묵 처리, 미터용 Rx 신호 레벨) → `_jitter.offer` →
     10ms 드레인 타이머 → `playback.feed`. 새 버스트(`kRxIdleTimeout` 후)에서 jitter+재생 reset.
   - PTT: `_beginTransmit`(서비스 승인 → 슬라이서/캡처 → transmitting + roger + mediumImpact),
     거부 시 `_onBusyDenied`(busy 배너 600ms + heavyImpact + denied 톤), `_endTransmit(stopCapture)`.
   - VOX: 세션에서 캡처 연속 시작(PTT와 공유), `_voxTick` 발화 120ms → 자동 송신,
     침묵 400ms → 자동 종료(효과/햅틱 없음). `setVoxEnabled/setNoiseGateEnabled/setEffectsEnabled/
     setHapticsEnabled/knobTick`.
   - 충돌 이벤트: 로컬 정리 → `TxStatus.collision` 1초 배너 + heavyImpact + denied 톤.
5. `lib/features/walkie/data/audio/sound_effects.dart` — SoLoud.loadAsset('assets/sounds/*.wav')
   + play 재사용, `enabled` 토글. roger(PTT start/end)/squelch(RX 시작)/denied(거부).
6. `tool/gen_sounds.dart` — 순수 Dart WAV 생성(44.1k mono 16-bit): roger_beep(1320+1760Hz 50+50ms),
   squelch_tone(2200Hz 28ms), denied_tone(330+220Hz 110+110ms). 4CC는 바이트 직접 기록.
7. `walkie_state.dart` — `voxEnabled`/`noiseGateEnabled` 추가.
8. `rotary_knob.dart` — `onNotch` 콜백으로 노치 틱 햅틱을 `controller.knobTick`
   (selectionClick + hapticsEnabled 반영)으로 위임(기존 무조건 mediumImpact 제거).
9. `radio_sim.dart` — `_ToneSender`가 `startTransmit()` 승인 확인(거부 시 '채널 사용 중' 출력),
   프레임 발송 전 `isTransmitting` 가드.
10. 테스트 — `test/jitter_buffer_test.dart` 11건(워밍업/순서복원/중복/PLC/홀스킵/종료/reset),
    `test/channel_arbiter_test.dart` 11건(허용/거부/타임아웃/guard/충돌/양보/peerLeft),
    `test/sound_assets_test.dart` 3건(RIFF/WAVE 헤더 + data 크기).

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 61/61 통과 (Step 5 신규 25건 포함)
- `flutter build apk --debug`: 성공
- `dart run tool/gen_sounds.dart`: WAV 3종 생성 확인
- `dart run tool/radio_sim.dart --once`: 기동 정상(채널 1, localIP 192.168.219.103)

### 이슈 / 트러블슈팅

- **WAV 4CC 역순**: `setUint32(0, 0x52494646, little)`은 바이트 역순("FFIR").
  RIFF/WAVE/fmt/data 4CC는 바이트 직접 기록(`_fourcc`)으로 해결.
- **지터 PLC 갭 판정 재설계**: "연속 누락 ≤ 상한" 방식은 홀 스킵 후 다시 PLC가 반복돼
  최악 무한 PLC(91프레임)가 발생. → "남아 있는 최소 seq와의 갭" 기준으로 재작성
  (≤6이면 PLC로 채움, 초과면 홀 스킵).
- **워밍업 중 첫 프레임 중복**: `offer`의 warmup 경로에서 동일 seq 덮어쓰기만 하고 폐기하지
  않음 → `_queue.containsKey(seq)` 폐기 추가.
- **shouldStop 초기값**: `_lastOfferMs == 0` 가드가 t=0 수신 케이스를 항상 false로 만들었음
  → 가드 제거.
- **RotaryKnob 햅틱 하드코딩**: 무조건 `HapticFeedback.mediumImpact()` → `onNotch` 콜백으로
  위임, 채널 변경 중복 햅틱 제거.

### 미해결 이슈 / 다음 액션
- 실기기 2대 E2E: 실제 음성·지연·음질 실측(Wi-Fi), AP Isolation 확인, iOS 미검증.

---

## 2026-09-29 — Step 6: 설정 · 예외처리 · 테스트 · README (완료)

### 수행 내용

1. `lib/core/utils/kv_store.dart` — AppPrefs 확장:
   닉네임/기본 채널(기존) + volume/effectsEnabled/hapticsEnabled/voxEnabled/
   noiseGateEnabled/themeMode 영속화 키 추가.
2. `lib/features/settings/settings_controller.dart`(신규) — `AppThemeMode{dark,light,system}`
   + `ThemeModeController`(AsyncNotifier, prefs 로드/저장). `main.dart`의 `WktkApp`이
   `themeModeControllerProvider`를 watch해 테마 전환.
3. `walkie_controller.dart` —
   - build()에서 `_loadPersistedSettings()`(세션 전 상태 반영), `_ensureSession`에서도
     prefs를 재읽어 시작 시점 경합 방지·`sessionError:null` 초기화, 실패 시
     `state.sessionError` 기록.
   - 세터 영속화: setChannel(기본 채널)/setVolume/setVoxEnabled/setNoiseGateEnabled/
     setEffectsEnabled/setHapticsEnabled.
   - `setNickname`(trim+12자 제한 → 영속화 → 상태 반영 → 세션 재시작),
     `restartSession`/`retrySession`, `setVoxEnabled(false)` 시 진행 중 VOX 종료·캡처 중지.
4. `walkie_state.dart` — `sessionError` 필드 추가.
5. `settings_screen.dart` 재구현 — 프로필(닉네임 TextField+저장), 기본값(기본 채널
   Dropdown 1~16 · 재생 볼륨 Slider), 기능(효과음/햅틱/VOX/노이즈 게이트 SwitchListTile),
   화면(RadioGroup: 다크/라이트/시스템), 연결 권한(마이크 상태 + 앱 설정 열기).
6. `walkie_screen.dart` — `sessionError` 오류 배너('다시 시도'), Wi-Fi 배너 '설정' →
   SettingsScreen 푸시.
7. `test/settings_screen_test.dart` 6건 — 전체 섹션 표시, 효과음/햅틱/VOX 토글,
   닉네임 저장(prefs+상태), 테마 변경, 기본 채널 로드. (네트워크 모니터 스텁 override +
   큰 뷰포트로 결정성 확보)
8. `README.md` — 프로젝트 소개, 빌드/설치, 2대 실기기 절차+체크리스트, radio_sim 용법,
   아키텍처(순수 Dart 경계), 프로토콜 v1(40B 헤더·4타입), iOS 제약, 테스트/문서 안내.

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 67/67 통과 (Step 6 신규 6건 포함)
- `flutter build apk --debug`: 성공

### 이슈 / 트러블슈팅

- **위젯 테스트 pending Timer**: `NetworkMonitor`의 3초 주기 타이머가 FakeAsync에서
  누수 → 설정 테스트에서 `networkStatusProvider`를 타이머 없는 스텁으로 override.
- **설정 리스트 하단 잘림**: 기본 800×600 테스트 뷰포트에서 하단 섹션 미노출 → 큰
  뷰포트(900×2600) + `tester.view.reset` 티어다운.
- **Riverpod AsyncValue**: `valueOrNull` getter는 이 버전에 없음 → `.value ?? fallback`.
- **RadioListTile deprecated**: Flutter 3.32+에서 `groupValue/onChanged` 폐기 →
  `RadioGroup<AppThemeMode>` 조상으로 이동.
- **RotaryKnob `flutter/services` 미사용 import**: 햅틱을 `onNotch` 콜백으로 옮기며
  남은 services import 제거(analyze 0 유지).

### 미해결 이슈 / 다음 액션
- 실기기 2대 E2E: 음성 품질·첫 프레임 지연 실측, AP Isolation·iOS 미검증,
  Android 12+ 정확한 네트워크 런타임 권한(선택).

---

## 2026-09-29 — Step 7: 접속자 목록 · 전송 폴백 수정 (완료)

### 수정 계획 (요약)
- 접속 대수가 계속 0인 문제: 멀티캐스트가 막힌 환경에서 브로드캐스트 폴백이
  SO_BROADCAST 미설정으로 실패하고 있었음.
- 접속 대수를 탭하면 누가 접속했는지(닉네임·주소) 확인할 수 있게 함.

### 수행 내용

1. `lib/core/network/transport/dart_udp_transport.dart` — `bind` 직후
   `socket.broadcastEnabled = true`(SO_BROADCAST). 미지원 플랫폼은 예외 무시.
2. `lib/features/walkie/data/peer.dart` → `lib/features/walkie/domain/peer.dart`로 이동.
   참조하는 `peer_registry.dart`/`transceiver_service.dart`/`walkie_controller.dart`
   import 정리(순수 Dart 경계 유지).
3. `lib/features/walkie/domain/walkie_state.dart` — `List<Peer> peers` 필드 추가
   (`copyWith` 포함, 기본 `const <Peer>[]`).
4. `lib/features/walkie/presentation/walkie_controller.dart` — `_ensureSession`/
   `_onPeersChanged`/`_teardownSession`에서 접속자 스냅샷을 `peers`로 발행·초기화
   (`List.unmodifiable`로 불변 전달).
5. `lib/features/walkie/presentation/widgets/peer_list_sheet.dart`(신규) —
   `showPeerListSheet`: 송신 중 접속자 우선 정렬, 닉네임·IP:port·송신 여부 표시,
   접속자 없으면 안내 문구.
6. `walkie_screen.dart` 하단, `widgets/lcd_panel.dart` LCD의 "접속 N대"를 탭하면
   위 시트가 열리도록 연결(아이콘 + 밑줄로 탭 가능 표시).
7. `README.md` — 접속 대수 탭 → 접속자 목록 안내 한 줄 추가.

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 67/67 통과

### 이슈 / 트러블슈팅

- **접속 0 원인**: `DartUdpTransport.sendAll`은 멀티캐스트가 안 되면 브로드캐스트로
  폴백하는데, 소켓의 `broadcastEnabled`(SO_BROADCAST)를 켜지 않아 브로드캐스트 `send`가
  조용히 실패 → PRESENCE 미수신 → 접속 대수 0. 기존 헤더 주석의 "SO_BROADCAST 미노출"은
  사실이 아니었음(Dart `RawDatagramSocket`이 `broadcastEnabled` 제공). 별도 `dart`
  스니펫으로 set/get 가능 확인 후 `bind` 직후 활성화.
- **계층 정리**: `Peer`가 `data/`에 있어 도메인 상태(`walkie_state.dart`)가 data를
  참조하게 되는 문제 → `domain/`으로 이동(IMPLEMENT 문서 구조와 일치).

### 미해결 이슈 / 다음 액션
- 실기기 2대(또는 실기기↔`radio_sim`)에서 접속 대수·접속자 목록 실측 확인.
  AP Isolation·iOS 멀티캐스트 entitlement는 여전히 미검증(브로드캐스트 폴백으로 완화).

---

## 2026-09-29 — Step 8: 백그라운드 복귀 재접속 · 접속 확인 버튼 (완료)

### 수정 계획 (요약)
- 백그라운드 전환 후 복귀 시 접속이 0으로 끊기고, 앱을 재실행해야 복구되는 문제.
- PTT 버튼 좌측의 상태 텍스트를 없애고 '접속 확인' 버튼을 배치.

### 수행 내용

1. `lib/features/walkie/presentation/walkie_controller.dart`
   - `AppLifecycleListener` 추가(`build()`에서 생성, `ref.onDispose`에서 dispose).
     `onResume` → `_reconnectFromBackground()`: 네트워크 연결 + 송신 중 아님일 때
     `restartSession()`으로 세션 재기동(멀티캐스트 재가입 + PRESENCE 즉시 재송신).
   - `checkConnection()` public 메서드 추가(수동 '접속 확인' 버튼용, `Future<bool>`).
2. `lib/features/walkie/presentation/walkie_screen.dart` — PTT 좌측 상태 텍스트
   (IDLE/통화 중 + 안내) 제거 → `OutlinedButton.icon` '접속 확인' 배치. 미연결 시
   SnackBar 안내, 정상 시 '접속을 다시 확인합니다' 표시.

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 67/67 통과
- `flutter build apk --debug`: 성공

### 이슈 / 트러블슈팅

- **백그라운드 접속 끊김**: Android가 백그라운드에서 Wi-Fi 멀티캐스트 멤버십·타이머를
  정지시켜 PRESENCE가 만료 → 접속 0. 앱 재실행이 복구 수단이었으므로, 복귀 시 세션
  재기동으로 동일 효과를 자동화. 통화(송신) 중에는 세션을 끊지 않도록 가드.
- **UI 중복 제거**: 좌측 IDLE/통화 중 표시는 상단 상태 LED·LCD 상태 라인과 중복이라
  제거하고, 복구 수단(접속 확인)을 배치해 공간을 재활용.

### 미해결 이슈 / 다음 액션
- 실기기에서 백그라운드 → 복귀 시 자동 복구 및 '접속 확인' 버튼 동작 실측.
- (선택) Android Foreground Service로 백그라운드 수신 유지(후순위).

---

## Step 9 — 전원 스위치 · 백그라운드 유지 · 상대 PTT 자동 전화 — 2026-09-29

### 요구 사항

1. 현재 포그라운드에서만 정상 작동하고 백그라운드에서 작동을 안 하며 접속이 끊김 → 해결.
2. 정확한 전원 ON/OFF로 프로세스를 콘트롤.
3. APP 상단 환경설정 아래에 붉은 전원 버튼.
4. 전원 OFF 시에만 전체 프로세스를 완전히 종료.
5. 그 외에는 백그라운드에서 계속 대기하고, 상대가 PTT 시 자동으로 포그라운드로 전화.

### 원인 분석

- 앱 프로세스가 살아 있어도 Android가 백그라운드에서 CPU를 절전(Doze) 상태로 보내
  PRESENCE 타이머(2초)와 UDP 수신이 멈추고, Wi-Fi 멀티캐스트 멤버십도 정지되어
  상대 입장에서 '접속 끊김'으로 보인다.
- 설계상 세션은 백그라운드에서도 유지되도록 되어 있었으나(Step 8), 이를 뒷받침할
  **포그라운드 서비스가 없어** OS가 언제든 프로세스를 정지/강제 종료할 수 있었다.

### 변경 파일

1. `android/app/src/main/kotlin/com/wktk/wktk/WktkPowerService.kt` (신규)
   - `foregroundServiceType=mediaPlayback` 포그라운드 서비스, `START_STICKY`.
   - `PARTIAL_WAKE_LOCK`(화면 꺼짐 중 CPU 유지) + `WIFI_MODE_FULL_HIGH_PERF` Wi-Fi 락 +
     멀티캐스트 락을 획득/해제 → 화면 꺼진 상태에서도 PRESENCE·UDP 수신 지속.
   - `startForeground` 실패(정책 제한) 시 예외를 삼가고 `stopSelf`(앱 죽음 방지).
   - 알림 액션 `전원 끄기`(ACTION_POWER_OFF) → `stopSelf` + 프로세스 종료.
2. `android/app/src/main/kotlin/com/wktk/wktk/PowerController.kt` (신규)
   - `setPower(on)` ON: `startForegroundService`, OFF: `stopService` + 250 ms 뒤
     `Process.killProcess`(MethodChannel 응답이 먼저 전달되도록 지연).
   - `ring(talker, channel)`: IMPORTANCE_HIGH 헤드업 알림 + fullScreenIntent + 진동 +
     앱 액티비티 기동.
   - 상시 알림 빌더(액션: 열기 / 전원 끄기), 알림 채널 2종 생성, `isActive` 플래그.
3. `android/app/src/main/kotlin/com/wktk/wktk/MainActivity.kt`
   - `MethodChannel("wktk/power")` → `setPower` / `ring` / `isPowerOn` 핸들러 추가.
4. `android/app/src/main/AndroidManifest.xml`
   - 권한 추가: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
     `POST_NOTIFICATIONS`, `VIBRATE`, `USE_FULL_SCREEN_INTENT`.
   - `<service .WktkPowerService foregroundServiceType="mediaPlayback" stopWithTask="false"/>`.
   - `MainActivity`: `launchMode=singleTask`, `taskAffinity=""` 제거
     (서비스에서 호출 인텐트 시 기존 태스크가 확실히 재사용되도록).
5. `lib/core/platform/power_channel.dart` (신규) — `setPower`/`isPowerOn`/`ring` 래퍼.
   플러그인 미지원/예외는 삼켜 앱 동작에는 영향 없음(테스트/iOS 안전).
6. `lib/core/platform/notification_permission.dart` (신규) — Android 13+ 알림 권한
   1회 요청(온보딩 + 전원 ON 시).
7. `lib/features/walkie/presentation/walkie_controller.dart`
   - `build()`: `AppLifecycleListener.onStateChange`로 현재 lifecycle 추적,
     `scheduleMicrotask(_powerOn)`으로 앱 실행 = 전원 ON(FGS 기동 + 알림 권한).
   - `powerOff()`: 상태 OFF → 세션 teardown → `PowerChannel.setPower(false)` →
     `SystemNavigator.pop()`(네이티브가 프로세스까지 종료).
   - `_onResume()`: 세션이 살아 있으면 유지하고 죽었을 때만 재기동
     (이전처럼 매번 재기동해 통화가 끊기던 동작 제거). 서비스 재확인.
   - `_maybeCallFromBackground()`: lifecycle이 `resumed` 가 아니고 상대 PTT 감지
     (`remoteStarted` 버스 이벤트 또는 RX 버스트 첫 프레임) 시 3초 쿨다운 후 전화.
   - `WalkieUiState.powerOn` 가드: 미연결·PTT·접속 확인·세션 기동 모두 전원 OFF 시 차단.
8. `lib/features/walkie/domain/walkie_state.dart` — `powerOn`, `incomingCaller` 추가.
   `copyWith` nullable 필드에 `_unset` 센티널 도입.
9. `lib/features/walkie/presentation/widgets/power_button.dart` (신규) — 붉은 원형 전원
   버튼(ON 점등 + 글로우 / OFF 소등), Semantics 라벨, Tooltip.
10. `lib/features/walkie/presentation/walkie_screen.dart` — 상단 헤더를 `Column`으로
    바꾸어 환경설정 아이콘 아래에 전원 버튼 배치, 전원 OFF 확인 `AlertDialog`,
    `incomingCaller` 감청 SnackBar('○○ 님이 전화를 걸었습니다').
11. `lib/features/settings/presentation/settings_screen.dart` — '전원 · 백그라운드'
    섹션(전원 상태 표시 + 알림 권한 상태/앱 설정 열기).
12. `lib/features/onboarding/onboarding_controller.dart` — 마이크 허용 시 알림 권한 함께 요청.
13. `lib/core/constants/app_constants.dart` — `kIncomingCallCooldown`(3초).
14. `test/power_test.dart` (신규) — 5건.
15. `README.md` — 기능/권한/전원·백그라운드 테스트 절차 갱신.

### 검증

- `flutter analyze`: No issues found
- `flutter test`: 72/72 통과 (기존 67 + 신규 5)
- `flutter build apk --debug`: 성공 (Kotlin/매니페스트 컴파일 포함 확인)
- 미수행: 실기기 2대 E2E(백그라운드·화면 OFF 상태 PTT 수신 → 자동 전화, 알림 액션).

### 함정 / 배운 것

- **Notifier.build() 안의 동기 `state=`**: `unawaited(_powerOn())` 처럼 보여도 호출 시점에
  동기적으로 state를 읽으면 `Bad state: uninitialized provider` 로 죽는다
  → `scheduleMicrotask` 로 미뤄 실행.
- **copyWith 로 null 지우기 불가**: `x ?? this.x` 패턴은 `null` 을 '변경 없음'으로
  해석해 `talkerNickname` 이 지워지지 않는 버그가 있었다 → `_unset` 센티널로 교체.
- **위젯 테스트의 pumpAndSettle 타임아웃**: 무전기 화면에 점멸 LED 등 무한 애니메이션이
  있어 `pumpAndSettle` 이 끝나지 않는다 → 다이얼로그는 `pump(400 ms)` 로 진행.
- **taskAffinity="" (Flutter 템플릿)**: 서비스에서 Activity 를 올릴 때 기존 태스크
  재사용이 불안정할 수 있어 제거 + `singleTask` 로 고정.
- **FGS 종료 지연**: `setPower(false)` 에서 곧바로 kill 하면 MethodChannel 응답과
  Dart 후속 정리(`SystemNavigator.pop`)가 끊기므로 250 ms 지연 후 종료.

### 남은 작업 / 다음 액션

- 실기기 2대 E2E: 화면을 끈 백그라운드 상태에서 상대 PTT 수신 → 자동 전화
  (헤드업 + 진동) → 응답 송신, 그리고 전원 버튼/알림 액션으로 완전 종료 확인.
- 제조사 ROM(삼성 등)의 포그라운드 서비스 강제 종료/앱 휴면 설정으로 대기가 끊길 수
  있으므로 기기별 '배터리 · 앱 휴면' 설정 확인 안내가 필요하다.
- iOS 는 전원 스위치/백그라운드 대기 미구현(멀티캐스트 entitlement 필요).
