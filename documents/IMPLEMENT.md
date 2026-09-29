# 워키토키(P2P) Flutter 앱 — 구현 계획

> 같은 Wi-Fi(LAN)에서 서버 없이 실시간 음성 대화(Push-to-Talk)를 하는 Flutter 앱.
> 본 문서는 **개발 초기 및 수정 계획**을 한국어로 기록하며, 각 Step 착수 전에 갱신한다.
> 실제 수행 결과는 `documents/TASKS_EXECUTED.md`에 누적 기록한다.

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|---|---|
| 프로젝트 루트 | `C:\skns\wktk` |
| 앱 이름 | `wktk` (워키토키) |
| 프레임워크 | Flutter 3.47.5 stable / Dart 3.13.4 |
| 대상 플랫폼 | Android, iOS (세로 모드 고정) |
| 네트워크 | 서버 없는 UDP P2P (같은 서브넷 한정) |
| 코덱 | 16 kHz / 16 bit / mono PCM, 20 ms(640 B) 프레임 |
| UI 컨셉 | 레트로-모던 무전기(스큐어모피즘 + 플랫 중간), 다크 기본 |

## 2. 확정된 기술 결정 (D1~D8)

| ID | 결정 | 내용 | 근거 |
|---|---|---|---|
| D1 | 툴체인 | 이 PC에 Flutter stable + JDK17 + Android SDK/NDK 설치 | analyze/test 직접 검증이 Acceptance Criteria의 전제 |
| D2 | 전송 계층 | 3중 경로(멀티캐스트 → 브로드캐스트 → 유니캐스트 메쉬) 자동 폴백 + 수동 IP 입력 | Apple 문서상 iOS 14+는 **브로드캐스트도** `com.apple.developer.networking.multicast` restricted entitlement 필요 → 유니캐스트가 entitlement 없이 확실히 되는 유일한 경로 |
| D3 | 오디오 | `record 7.1.1`(캡처) + `flutter_soloud 5.1.2`(PCM16 스트리밍 재생·시각화) | 양 플랫폼 스트리밍 PCM 지원이 확인된 유일 조합. `flutter_sound`(저활성), `sound_stream`(초기 개발 단계) 기각 |
| D4 | UI 문안 | 한국어 + 영문 병기 (예: "채널 사용 중 / CH BUSY") | 요구 스펙 표기 기준 |
| D5 | 포인트 컬러 | 앰버 오렌지 `#FF9A21` | 다크 기체 톤에서 LCD 가독성 확보 |
| D6 | 선택 기능 | VOX, 수신 노이즈 게이트, 다크/라이트 테마 **포함**. Android FGS 백그라운드 수신은 **후순위** | 핵심 8개 기능 완성도 우선 |
| D7 | 테스트 | PC용 CLI 가상 무전기 `tool/radio_sim.dart` 제공 | 기기 2대 부재 시 단독 검증 가능 |
| D8 | 7-세그먼트 | CustomPainter 직접 렌더 (이미지/폰트 asset 불필요) | 해상도 무관 선명, 라이선스 이슈 제거 |
| — | 상태관리 | `flutter_riverpod 3.4.3`, **코드-gen 없이 수동 Provider** | `build_runner` 완전 배제, 빌드 파이프라인 단순화 |
| — | 저장 | `shared_preferences` | 설정/닉네임 로컬 저장 |
| — | 화면 유지 | `wakelock_plus` | 통화 중 화면 꺼짐 방지 |
| — | 효과음 | `tool/gen_sounds.dart`로 WAV 오프라인 생성 → `assets/sounds/` | 런타임 합성/다운로드 불필요, 재생 지연 0 |
| — | 보조 폰트 | `google_fonts` + `allowRuntimeFetching = false` (asset 번들) | 인터넷 없이 동작, 7-세그는 직접 그림 |

## 3. 아키텍처

```
UI (WalkieScreen / SettingsScreen / OnboardingScreen)
  └─ WalkieController (Riverpod Notifier) : PTT, 채널, 볼륨, txState
       └─ TransceiverService (단일 수명주기 소유자)
            ├─ UdpTransport            : RX 고정포트 소켓 + TX ephemeral 소켓, 경로 자동 선택
            ├─ AudioCapture            : record → 640 B 프레임 슬라이싱
            ├─ AudioPlayback           : flutter_soloud bufferStream (16 kHz mono s16le)
            ├─ JitterBuffer (peer별)   : 순서복원 · 중복폐기 · 손실 은폐
            ├─ PeerRegistry            : PRESENCE 수신/만료(8 s)
            └─ ChannelArbiter          : 반이중 버스 소유권 + 충돌 처리
```

**리소스 소유 원칙**: `TransceiverService`가 소켓·녹음 스트림·재생 엔진의 유일 소유자.
`dispose()` 한 번으로 전부 정리하여 누수를 원천 차단한다.

### 데이터 흐름
- **TX**: PTT Down → 버스 점유 확인 → `record.startStream(16k/mono/pcm16bits)` → 청크 누적 →
  640 B 절단 → `AUDIO` 패킷 인코딩 → 3경로 동시 발송
- **RX**: 소켓 수신 → 코덱 디코딩 → 자기 ID/중복 seq 폐기 → JitterBuffer →
  `arrival + 60 ms <= now` 지난 프레임만 `addAudioDataStream` → 스피커

## 4. 프로토콜 명세

### 4.1 BaseHeader (40 bytes, little-endian)

| offset | size | 필드 | 설명 |
|---|---|---|---|
| 0 | 2 | magic | `0x4B57` ('WK') |
| 2 | 1 | version | 1 |
| 3 | 1 | type | 0=PRESENCE, 1=TX_START, 2=TX_END, 3=AUDIO |
| 4 | 2 | headerLen | 40 |
| 6 | 2 | payloadLen | body 바이트 수 |
| 8 | 4 | seq | 채널 내 단조 증가 |
| 12 | 1 | channel | 1~16 |
| 13 | 1 | codec | 0=PCM_S16LE_16K_MONO, 1=OPUS(예약) |
| 14 | 2 | sampleRate | 16000 |
| 16 | 8 | timestampMs | 송신측 단조 시계 (지연 측정용) |
| 24 | 16 | senderId | UUID v4 raw |

> **암호화 확장점(EXTENSION POINT)**: 4~6 바이트 영역에 `flags`(bit0=crypt)를 추가할 계획.
> `crypt=1`일 때 header 뒤에 nonce(12 B) + authTag(16 B)을 삽입하는 형태로 확장하며,
> 지금은 `0`으로 고정해 wire 호환을 유지한다. 구현 시 `PacketCodec`에 주석으로 명시.

### 4.2 Body

| 타입 | body |
|---|---|
| AUDIO | PCM16 LE raw (`payloadLen` = 640 또는 발화 종료 시 잔여 바이트) |
| PRESENCE | `u8 nickLen` + nick(≤32 B UTF-8) + `u8 txActive` |
| TX_START | `u8 nickLen` + nick + `u16 talkMs`(0) |
| TX_END | `u8 nickLen` + nick |

### 4.3 채널 매핑

- 포트: `45000 + channel`
- 멀티캐스트 그룹: `239.255.42.<channel>`
- 브로드캐스트: `255.255.255.255` (+ 이미지로 추정한 서브넷 브로드캐스트 주소)
- 유니캐스트: PRESENCE로 학습한 상대 IP 동일 포트

> **중복 제거가 추가 비용 없는 이유**: 3경로 동시 발송 → 동일 패킷이 최대 3회 도착 →
> JitterBuffer의 `(senderId, seq)` 중복 폐기로 재생은 1회만 수행.

## 5. 상수 정의 (`lib/core/constants/app_constants.dart`)

```
kMagic=0x4B57, kVersion=1, kBasePort=45000, kMulticastPrefix='239.255.42'
kSampleRate=16000, kFrameMs=20, kFrameSamples=320, kFrameBytes=640
kPresenceIntervalMs=2000, kPeerTimeoutMs=8000
kJitterBufferMs=60, kJitterMinMs=40, kJitterMaxMs=120
kTxIdleTimeoutMs=400, kTxGuardMs=250, kRxIdleTimeoutMs=1200
kCollisionWindowMs=250, kDefaultVolume=0.7, kMaxNicknameBytes=32
```

## 6. 반이중 상태 머신 (`ChannelArbiter`)

```
idle ──PTT──▶ txLocal ──PTT up──▶ idle
  ▲               │
  │ yield         │ peer TX_START 수신(Δt ≤ 250 ms) → 충돌
  └───────────────┘
rxRemote ◀── 타인 TX_START        busyOwner = (peerId, since)
  │  ▲
  │  └── TX_END 수신 / 400 ms 무수신 / 상대 이탈 → 해제
  └── 이 상태에서 PTT down 시도 → denied (채널 사용 중 + 햅틱)

- TX_END 수신 후 kTxGuardMs(250 ms) 유지 → 발화 테일 컷 방지
- PRESENCE의 txActive 플래그로 신규 접속자도 즉시 버스 상태 인지
- 양측이 250 ms 내 동시 TX_START 감지 시 양측 중단 + LCD "충돌" 1초 표시
```

## 7. JitterBuffer 알고리즘

- 저장소: `Map<int, (arrivalMs, bytes)>` + `nextSeq`
- 재생 조건: `arrival + kJitterBufferMs <= now`
- seq 역전/중복 → 폐기 / gap → 마지막 샘플 hold 20 ms 음성 은폐(PLC) /
  120 ms 초과 공백 → 침묵 채우기 + RX 종료
- **TX 세션 경계에서 버퍼 리셋** (발화 불연속), `dispose()`에서 타이머·큐 정리

## 8. 지연 예산 (목표 체감 300 ms 이내)

| 구간 | 예산 |
|---|---|
| 캡처 청크 누적 | Step 4에서 실측 (`record` 스트림 청크 크기에 의존) |
| LAN 네트워크 | ~5 ms |
| 지터 버퍼 | 60 ms |
| SoLoud 출력 버퍼 | 1024 @ 48 kHz = 약 21 ms |
| 출력 지연 | ~30 ms |

## 9. UI 위젯 구성 (CustomPainter 기반, 이미지 asset 0개)

| 위젯 | 내용 |
|---|---|
| `AntennaWidget` | 안테나 마스트, TX 시 글로우 펄스 |
| `StatusLedWidget` | 대기(녹색 점멸) / TX(적색) / RX(녹색) |
| `LcdPanel` | 액정 배경(그라디언트+미세 그리드+시드 노이즈), 7-세그 채널 번호, 접속자 수, 송신자 닉, 신호 미터 |
| `SpeakerGrilleWidget` | 촘촘한 가로 슬릿, 수신 진폭에 반응 |
| `RotaryKnob` | 드래그 회전·노치 스냅(채널 16 / 볼륨 20)·햅틱 틱·CustomPainter |
| `PttButton` | 화면 폭 42 %, 눌림 물리 애니메이션 + TX 시 포인트 컬러 링 펄스 |
| `LevelMeter` / `StatusBanner` | TX/RX 레벨 바, Wi-Fi 미연결·권한 거부 배너 |
| 공통 | 세로 고정, `Semantics` 라벨, PTT는 하단 1/3(엄지 도달), 햅틱 4종(PTT / 노브 틱 / 채널 변경 / 거부) |

## 10. 플랫폼 설정

**Android** (`minSdk 24`, Kotlin)
- 권한: `INTERNET`, `RECORD_AUDIO`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`,
  `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, (Step 9 추가) `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `VIBRATE`,
  `USE_FULL_SCREEN_INTENT`
- `MethodChannel('wktk/multicast')` → `acquire` / `release`
  : `WifiManager.createMulticastLock("wktk")`, `setReferenceCounted(false)`
  — **멀티캐스트 join보다 먼저 획득**해야 한다.
- `MethodChannel('wktk/power')` → `setPower`(포그라운드 서비스 기동/종료+프로세스 종료) /
  `ring`(헤드업 알림 + 진동 + 액티비티 기동) / `isPowerOn`
- `MethodChannel('wktk/audio_session')` → 오디오 세션/경로 설정
- 포그라운드 서비스 `WktkPowerService`(`foregroundServiceType=mediaPlayback`,
  `stopWithTask=false`): 부분 웨이크락 + Wi-Fi 락 + 멀티캐스트 락, 상시 알림
  (`열기`/`전원 끄기` 액션). `MainActivity`는 `launchMode=singleTask`,
  `taskAffinity` 제거 → 서비스에서 호출 인텐트로 기존 태스크가 확실히 올라온다.

**iOS** (Swift, `Info.plist`)
- `NSMicrophoneUsageDescription`, `NSLocalNetworkUsageDescription`
- **`NSBonjourServices`는 넣지 않는다.** raw UDP 소켓은 Bonjour가 불필요하며
  잘못 기재하면 App Store 심사 리스크가 된다. 사유는 README에 명시한다.
- `AVAudioSession`: category `.playAndRecord`, mode `.default`,
  options `.defaultToSpeaker | .allowBluetooth`
- 멀티캐스트 join은 entitlement 보유 시에만 분기 실행, 없으면 자동으로
  broadcast + unicast 모드로 진입한다.
- **iOS 실기 빌드는 Mac이 필요하므로 이 PC에서는 설정 코드 작성까지만 검증한다.**

## 11. 파일 구조

```
lib/main.dart
lib/app/{theme.dart, router.dart}
lib/core/constants/app_constants.dart
lib/core/network/{packet.dart, packet_codec.dart, subnet.dart,
                 transport/{transport.dart, dart_udp_transport.dart,
                            native/multicast_lock_channel.dart, audio_session_channel.dart}}
lib/core/platform/{power_channel.dart, notification_permission.dart}
lib/core/audio/{audio_capture.dart, audio_playback.dart, pcm_slicer.dart,
                jitter_buffer.dart, rms.dart}
lib/core/utils/{clock.dart, logger.dart}
lib/features/walkie/domain/{peer.dart, channel.dart, tx_state.dart, walkie_state.dart}
lib/features/walkie/data/{transceiver_service.dart, peer_registry.dart, channel_arbiter.dart}
lib/features/walkie/presentation/{walkie_screen.dart, walkie_controller.dart, widgets/*}
lib/features/settings/{settings.dart, settings_controller.dart, settings_screen.dart}
lib/features/onboarding/{onboarding_screen.dart, onboarding_controller.dart}
assets/sounds/{roger_beep.wav, squelch.wav, denied.wav}
tool/{gen_sounds.dart, radio_sim.dart}
test/{packet_codec_test.dart, jitter_buffer_test.dart, channel_arbiter_test.dart,
      peer_registry_test.dart, pcm_slicer_test.dart, settings_test.dart,
      power_test.dart}
android/app/src/main/kotlin/com/wktk/wktk/{MainActivity.kt, PowerController.kt,
                                           WktkPowerService.kt}
```

## 12. 단계별 체크리스트

### Step 0 — 개발 환경 준비 `상태: 완료`
- [x] Flutter 3.47.5 stable 설치 (`C:\dev\flutter`) 및 PATH 등록
- [x] JDK 17 설치
- [x] Android SDK: platform-tools, platforms, build-tools, **NDK + CMake**
      (flutter_soloud의 Dart build hooks가 C++ 을 컴파일하므로 필수)
- [x] 라이선스 동의, 환경변수(`ANDROID_SDK_ROOT`, `JAVA_HOME`) 설정
- [x] `flutter doctor` / `flutter create` / `flutter analyze` 통과 확인
- **위험**: NDK/CMake 누락 시 `flutter build apk` 단계에서 처음 실패한다. SDK 설치 직후 선확인.

### Step 1 — 프로젝트 생성 · 테마 · 무전기 UI 뼈대 `상태: 완료`
- [x] `flutter create` (org 지정, android/ios 플랫폼)
- [x] `pubspec.yaml` 의존성 추가, 색상/타이포그래피 토큰 정의
- [x] 위젯 7종 구현(순수 UI, 상태 없음)
- [x] `assets/sounds` WAV 생성 스크립트(`tool/gen_sounds.dart`) 및 자산 등록
- [x] `tool/radio_sim.dart` 스캐폴드
- **검증**: `flutter analyze` 경고 0건, `dart format` 적용, 에뮬레이터에서 화면 확인
        → APK 디버그 빌드 성공(실기기 화면 확인은 Step 2 이후)

### Step 2 — 권한 처리 및 Wi-Fi 상태 감지 `상태: 완료`
- [x] 온보딩 화면(마이크 + 로컬 네트워크), 거부 시 설정 화면 이동 안내
- [x] `NetworkInterface.list()` 기반 사설 IPv4 탐지로 Wi-Fi 판정
- [x] 인터페이스 변경(와이파이 ↔ 모바일) 시 트랜스포트 재시작 (상태 연동; 트랜스포트는 Step 3에 연결)
- **검증**: analyze 0건, 권한 거부 경로 로그 확인
        → `flutter test` 7/7 통과(Pure 분류기 11건 + 위젯 2건), APK 디버그 빌드 성공

**Step 2 상세 설계** (착수 시 갱신)
- 런타임 권한은 **마이크(RECORD_AUDIO)**가 유일한 프롬프트 대상. Android 로컬네트워크(LAN)
  권한은 manifests에 이미 있는 `ACCESS_WIFI_STATE`/`CHANGE_WIFI_MULTICAST_STATE`로 충분하고,
  iOS 로컬네트워크 프롬프트는 첫 UDP 소켓 사용 시 OS가 자동 표시 → 온보딩 문구로만 안내.
- `NetworkMonitor`(Riverpod Notifier): 3초 주기로 `NetworkInterface.list()`에서 비루프백 IPv4 중
  사설 대역(10/8, 172.16/12, 192.168/16) 탐지 → `connected`/`NetKind{wifi,cellular}`/`localIPv4` 상태.
  분류는 순수 함수 `NetworkClassifier.{isPrivateIPv4, classify}`로 분리(테스트 가능).
- `WalkieController`는 `ref.listen(networkStatusProvider)`로 `wifiOk`만 갱신(채널/볼륨 변경 유지). PTT는
  Wi-Fi 미연결 시 햅틱과 함께 무시.
- 첫 실행 분기: `onboardingDoneProvider`(shared_preferences) → 미완료면 `OnboardingScreen`,
  완료면 `WalkieScreen`. 거부/영구거부 시 `openAppSettings()` 안내와 LCD·배너 상태 연동.
- 파일: `lib/core/utils/kv_store.dart`, `lib/core/network/network_monitor.dart`,
  `lib/features/onboarding/*`, `lib/app/router.dart`(AppGate), `test/network_status_test.dart`.

### Step 3 — UDP 송수신 · Presence `상태: 완료`
- [x] `PacketCodec`(인코딩/디코딩) + 단위 테스트
- [x] `DartUdpTransport`(RX/TX 소켓, `joinMulticast`) — `broadcastEnabled`는 원자적 필드 확장으로
      대체, `multicastLoopback=false`는 API 부재로 `senderId` 필터로 대체
- [x] `PeerRegistry`(2 s 주기 PRESENCE, 8 s 만료)
- [x] Android `MulticastLock` MethodChannel (`wktk/multicast`)
- [x] `tool/radio_sim.dart` — 실제 트랜스포트로 PRESENCE/접속자 목록 표시
- **검증**: 코덱 10건, 레지스트리 4건, 통합(유니·멀티캐스트 loopback) 2건 → 총 24건 통과
  (`flutter analyze` 이슈 0, `flutter build apk --debug` 성공, `radio_sim --once` 접속자 없음 정상 종료)

**Step 3 구현 노트**
- 구현: `core/network/{packet, packet_codec, subnet}.dart`,
  `core/network/transport/{transport, dart_udp_transport}.dart`, `transport/native/multicast_lock_channel.dart`,
  `features/walkie/data/{peer, peer_registry, transceiver_service}.dart`, `MainActivity.kt`(MethodChannel).
- `subnet.dart`가 순수 분류기(`NetKind`/`NetworkClassifier`)를 소유하고 `network_monitor.dart`는 재수출 —
  `radio_sim`이 flutter 없이 동작.
- **단일 호스트 테스트의 함정**: `RawDatagramSocket`의 `sendTo` 대상 포트는 채널 포트(자기 바인딩 포트).
  실기기는 노드마다 다른 호스트의 같은 포트 번호라 정상이나, 루프백에서 같은 포트를 공유하면
  unicast 배달 대상이 비결정적 → `sendTo(..., port:)` 오버라이드만 테스트에 사용(운영 기본값은 채널 포트).
- Windows 호스트에서 브로드캐스트(255.255.255.255) 전송 오류(WSAEACCES 10013)는 소켓 스트림의
  비동기 오류로 표면화되므로 `socket.listen(onError: ...)`에서 흡수 (송신 경로 예외 무시 정책 유지).
- `flutter_tester.exe` UDP 허용 + `dart.exe` UDP 허용을 Windows 방화벽에 추가(호스트 검증용).

### Step 4 — PTT 오디오 경로 `상태: 완료`
- [x] `AudioCapture`(record 16k/mono/pcm16) + `PcmSlicer`(640 B 절단)
- [x] `AudioPlayback`(flutter_soloud `setBufferStream`/`addAudioDataStream`)
- [x] PTT 누름/뗌에 따른 송신 시작/종료
- [ ] 캡처 청크 실측 → 지연 예산 반영 (실기기 검증 단계에서 수정)
- **검증**: 단일 기기 + PC `radio_sim` 간 실제 음성 송수신 (기기 연결 시 진행)

**Step 4 상세 설계**
- 오디오 플러그인(record, flutter_soloud)은 **앱 쪽(flutter 의존)에만** 두고, 순수 Dart 경계는 유지한다:
  `TransceiverService`는 TX_START/TX_END/AUDIO 패킷과 `onAudio` 스트림만 다루고,
  `WalkieController`가 캡처/재생/슬라이서를 조합한다. `tool/radio_sim.dart`도 그대로 `dart run` 가능.
- `PcmSlicer`(순수 Dart): record `pcmStream`이 청크 크기가 불규칙하므로 누적 후 640 B(20 ms) 프레임으로 절단,
  꼬리는 유지. 초과분만 방출. 단위 테스트 대상.
- `AudioCapture`: `AudioRecorder.startStream(RecordConfig(pcm16bits, 16000, mono))` → `Stream<Uint8List>`.
  PTT down 시 시작, up 시 stop. (stream 모드는 파일 출력 불필요)
- `AudioPlayback`: `SoLoud.init()` + `setBufferStream(16000/mono/s16le/preserved, bufferingTimeNeeds 0.06,
  maxBuffer ~3 MB)` + `play()` 1회, 이후 수신 프레임마다 `addAudioDataStream`. TX 간격이 길면 유휴(재생 정지)
  상태가 되고 이어받으면 재생 재개. 다음 버스트 첫 프레임 시 `resetBufferStream`으로 잔여 버퍼 제거 → 번짐 방지.
- TX: PTT down → `service.startTransmit()`(TX_START 전송, presence txActive 세팅) → capture 시작 →
  프레임마다 `service.sendAudioFrame()`(AUDIO, seq++, timestamp) → RMS로 신호 레벨 갱신(5프레임마다). PTT up →
  capture 정지 → `stopTransmit()`(TX_END). PRESSENCE의 `txActive`는 `_transmitting` 반영.
- RX: AUDIO 수신 → senderId로 닉네임 조회 → `onAudio` 발행 → playback.feed + `receiving`/talkerNickname 표시,
  `kRxIdleTimeout`(1.2 s) 후 미수신 시 idle 복귀. PRESENCE/TX_START/TX_END의 `txActive`로 `channelBusy` 갱신.
- 서비스 라이프사이클: `build()`에서 `ref.listen(networkStatusProvider, fireImmediately:false)`로
  connected 시 세션 기동(localIPv4 주입), offline 시 해체. 콜백에서 `state=`는 build 종료 후이므로
  이전 Riverpod 트랩에서 회피. 위젯 테스트 환경은 인터페이스 없음 → disconnected 유지 → 세션 미기동.
  teardown 시 `ref.mounted` 확인 후 `state=` (위젯 테스트 dispose 중 "setState during build" 방지).
- 반이중 점유(ChannelArbiter)는 Step 5. Step 4에서는 수신 중에도 송신 시도 허용(전이중 대용).
- `radio_sim`: `--tone` 모드로 440 Hz 사인 AUDIO 프레임을 20 ms 간격 송신(순수 Dart 생성, `_ToneSender`가
  PTT 절차 모사), 수신 시 `[AUDIO] nick/바이트/지연` 통계 출력 → 기기 ↔ PC 상호 검증.
- 검증: `pcm_slicer_test.dart`(절단·경계·꼬리)+`pcm16Rms`, `flutter analyze`/`flutter test`/`flutter build apk
  --debug` 통과, 실기기↔`radio_sim --tone` 음성 도달(기기에서 톤 수신, PTT 시 sim 통계).
- 함정 기록: soloud는 `init()`(initialize 아님)/`deinit()` void; `AppConstants.kDefaultVolume`(0.7) 사용.

### Step 5 — 지터버퍼 · 반이중 · 효과음/햅틱 `상태: 완료`
- [x] `JitterBuffer` + 단위 테스트 (순수 Dart, nowMs 주입)
- [x] `ChannelArbiter` + 단위 테스트 (순수 Dart, nowMs 주입)
- [x] 거부 시 "채널 사용 중" 배너 + 햅틱(`TxStatus.busy` 600ms + heavyImpact + denied 톤)
- [x] 효과음(roger beep / squelch / denied), 햅틱 4종(PTT med/light, 노브 틱 selectionClick, 거부 heavy)
- [x] VOX, 수신 노이즈 게이트 (컨트롤러 로직, 설정 토글은 Step 6 노출)
- **검증**: 시나리오 단위 테스트(거부/충돌/지연 실측 대체)

**Step 5 상세 설계**
- `channel_arbiter.dart`(순수 Dart): 상태 idle/txLocal/rxRemote. `requestLocal`(busy면 false),
  `peerStart`(collisionWindow 내 → collision 이벤트, 이후 → 양보), `peerEnd`(guardMs 후 idle),
  `peerAudio`(idle 유지), `peerLeft`, `tick`(txIdle 자동 해제/rx 1200ms 타임아웃). `BusEvent`
  `{collision, remoteStarted}`는 `service.onBusEvent`로 상향.
- `service.startTransmit()` → `Future<bool>`(거부 시 false). RX txStart 시 `_handleRemoteStart`
  (충돌→로컬 interrupt + collision 이벤트, 양보→로컬 중단, 첫 busy 전이→remoteStarted=스퀠치).
  presence txActive=true면 감청 idle에서 busy로 선인지. presence timer에서 `arbiter.tick()` +
  txLocal 자동 해제 후 `_transmitting` 동기화.
- `jitter_buffer.dart`(순수 Dart): warmup(targetMs 도착 대기), 순서 복원, 중복/역전 폐기, 경미한
  갭(≤6프레임) PLC 홀드, 심한 갭 홀 스킵, `shouldStop`(maxDropMs). 컨트롤러가 10ms 드레인 타이머로
  bufferStream에 `feed`. 새 버스트(`kRxIdleTimeout` 후 첫 프레임)에서 `reset`+재생 버퍼 초기화.
- RX: 노이즈 게이트(`pcm16Rms < kNoiseGateThreshold`면 침묵 처리) → 지터 offer → drain → feed.
  RX 신호 레벨 미터는 게이트 통과 프레임 RMS로 갱신.
- VOX: `voxEnabled` 시 세션에서 캡처 연속 시작(`startStream` 공유). `_voxTick(RMS)`: 발화
  `kVoxEngageMs(120ms)` 연속 → 자동 `_beginTransmit`, `kVoxReleaseMs(400ms)` 침묵 → 자동 종료.
  VOX 발화/종료에는 효과음·햅틱 없이 조용히.
- PTT: `_beginTransmit`은 서비스 승인(거부 시 busy 플로우) → 슬라이서/캡처 시작 → `transmitting` +
  roger beep + mediumImpact. `_endTransmit(stopCapture)`는 PTT(캡처 중지)와 VOX(유지) 공용.
- 효과음: `tool/gen_sounds.dart`(순수 Dart)로 44.1k mono 16bit WAV 생성(`assets/sounds/` —
  roger_beep/squelch_tone/denied_tone, RIFF 4CC는 바이트 직접 기록). `SoundEffects`(flutter)는
  `SoLoud.loadAsset` + `play` 재사용, `enabled` 토글. pubspec assets 등록됨.
- 햅틱: 노브 노치 틱은 `RotaryKnob.onNotch` → `controller.knobTick`(selectionClick, `hapticsEnabled`
  반영). 채널 변경 햅틱은 노치 틱으로 통합(별도 중복 제거).
- 함정: WAV `setUint32` LE로 'RIFF' 4CC를 쓰면 바이트 역순("FFIR") → 4CC는 바이트 직접 기록.
  지터 PLC는 "연속 갭 ≤ 상한" 개념이 아니라 "남은 최소 seq와의 갭" 판정으로 재설계(상한 초과 홀 스킵).

### Step 6 — 설정 · 예외처리 · 테스트 · README `상태: 완료`
- [x] 설정 화면(닉네임, 기본 채널, 볼륨, 효과음, 햅틱, VOX, 노이즈 게이트, 테마)
- [x] 예외 처리(세션 소켓/오디오 시작 실패 → 배너 + 다시 시도, 마이크 캡처 실패 로그)
- [x] 단위·위젯 테스트 보강 (설정 화면 6건) — 총 67건
- [x] README(설치, 아키텍처, 프로토콜, iOS 제약, 2대 실기기 절차 + 체크리스트)
- **검증**: `flutter analyze` 0건, `flutter test` 67/67, APK 빌드 성공

**Step 6 상세 설계**
- `AppPrefs` 확장: nickname/defaultChannel은 기존, volume·effectsEnabled·hapticsEnabled·
  voxEnabled·noiseGateEnabled·themeMode를 추가해 모든 설정을 영속화.
- `settings_controller.dart`: `AppThemeMode{dark,light,system}` + `AsyncNotifier`
  `ThemeModeController`(prefs에서 로드, set 시 영속화). `main.dart`의 `WktkApp`이
  `themeModeControllerProvider`를 watch해 `MaterialApp.themeMode`에 반영.
- `WalkieController`:
  - build()에서 `_loadPersistedSettings()` — 저장된 설정을 세션 전에 상태로 반영.
  - `_ensureSession`에서도 prefs를 다시 읽어 시작 시점 경합을 회피하고
    `sessionError: null`로 초기화. 실패 시 `state.sessionError`에 메시지 저장.
  - 세터 전부 영속화: setChannel(기본 채널), setVolume, setVoxEnabled, setNoiseGateEnabled,
    setEffectsEnabled, setHapticsEnabled.
  - `setNickname`: trim·최대 12자 정리 → 영속화 → 상태 반영 → 세션 재시작(PRESENCE 반영).
    `restartSession`(teardown→ensure)/`retrySession`(배너의 다시 시도).
  - `setVoxEnabled(false)`에서 진행 중인 VOX 발화 종료·캡처 중지(PTT와 충돌 없게).
- `settings_screen.dart` 재구현(ConsumerStatefulWidget): 프로필(닉네임 TextField+저장),
  기본값(기본 채널 Dropdown 1~16, 재생 볼륨 Slider), 기능(효과음/햅틱/VOX/노이즈 게이트
  SwitchListTile), 화면(RadioGroup 다크/라이트/시스템), 연결 권한(마이크 상태+앱 설정).
- `walkie_screen.dart`: `sessionError`가 있으면 오류 배너(다시 시도), Wi-Fi 배너의
  '설정' 탭이 Settings 화면을 여는 동작 추가. 선택 테마와 무전기 본체의 고정
  하드웨어 톤(다크)은 분리(실제 무전기처럼 본체는 고정).
- 테스트(`settings_screen_test.dart` 6건): 네트워크 모니터를 타이머 없는 스텁으로
  override해 결정성 확보, 큰 뷰포트로 전체 섹션 표시 검증 + 닉네임 저장(prefs 반영)·
  효과음/햅틱/VOX 토글·테마 변경·기본 채널 로드.
- 함정: Riverpod AsyncValue의 `valueOrNull`은 이 버전에 없음 → `.value ?? fallback`.
  `RadioListTile.groupValue/onChanged`는 Flutter 3.32+에서 deprecated → `RadioGroup`
  조상으로 이동. 위젯 테스트의 pending Timer는 `NetworkMonitor` 3초 주기 타이머 원인
  → 테스트에서 override 제거. 설정 리스트는 기본 800×600 뷰포트에서 하단 잘림 → 큰
  뷰포트 + `tester.view.reset`.

### Step 7 — 접속자 목록 · 전송 폴백 수정 `상태: 완료`
- [x] 접속 대수 0 원인 수정: `DartUdpTransport` 바인딩 후 `broadcastEnabled = true`(SO_BROADCAST)
- [x] `Peer`를 `data/`→`domain/`으로 이동(도메인 엔티티로 정리)
- [x] `WalkieUiState`에 `peers` 목록 추가 + 컨트롤러가 PRESENCE 갱신/해제 시 발행
- [x] 접속자 목록 시트 + 하단/LCD "접속 N대" 탭 연결
- **검증**: `flutter analyze` 0건, `flutter test` 67/67

**Step 7 상세 설계**
- 문제: `sendAll`이 멀티캐스트 실패 시 브로드캐스트로 폴백하지만, 소켓의 SO_BROADCAST를
  켜지 않아(`broadcastEnabled` 미설정) 브로드캐스트 전송이 조용히 실패 → PRESENCE 미수신 →
  접속 대수가 계속 0. 기존 주석의 "SO_BROADCAST 미노출"은 사실이 아님(Dart
  `RawDatagramSocket`은 `broadcastEnabled` 제공).
- 해결: `start()`에서 bind 직후 `socket.broadcastEnabled = true`(지원 안 하는 플랫폼은 무시).
  iOS/일부 AP처럼 멀티캐스트가 막힌 환경에서 브로드캐스트 폴백이 실제로 동작하게 됨.
- 표시: `WalkieUiState.peers`에 접속자 스냅샷 보관, `_onPeersChanged`가 `List.unmodifiable`로
  전달. `showPeerListSheet`가 송신 중 접속자 우선 정렬 후 닉네임·주소·송신 여부를 바텀시트로
  표시하고, 접속자가 없으면 같은 채널/Wi-Fi 안내 문구를 보여준다.
- UI 연결: `walkie_screen.dart` 하단 "접속 N대"와 `lcd_panel.dart` LCD의 "접속 N대"를 탭하면
  시트가 열린다.

### Step 8 — 백그라운드 복귀 자동 재접속 · 접속 확인 버튼 `상태: 완료`
- [x] `AppLifecycleListener`로 포그라운드 복귀 시 세션 재기동(멀티캐스트 재가입 + PRESENCE 즉시 송신)
- [x] `WalkieController.checkConnection()` 추가 + PTT 좌측 상태 영역을 '접속 확인' 버튼으로 교체
- **검증**: `flutter analyze` 0건, `flutter test` 67/67, APK 재빌드

**Step 8 상세 설계**
- 문제: 앱을 백그라운드로 보내면 Android가 Wi-Fi 멀티캐스트 멤버십·타이머를 정지시켜
  PRESENCE가 만료 → 접속 대수 0. 앱을 다시 실행하면 복구됨(세션 재기동이 해법).
- 해결(자동): `WalkieController.build()`에서 `AppLifecycleListener(onResume)` 등록 →
  복귀 시 네트워크 연결 && 송신 중 아님을 확인 후 `restartSession()`(teardown→ensure).
- 해결(수동): PTT 좌측의 IDLE/통화 중 상태 텍스트(상단 LED·LCD와 중복)를 제거하고
  '접속 확인' `OutlinedButton` 배치 → `checkConnection()`. Wi-Fi 미연결이면 안내 SnackBar.

### Step 9 — 전원 스위치 · 백그라운드 유지 · 상대 PTT 자동 전화 `상태: 완료`
> 요구: (1) 현재 포그라운드에서만 동작하고 백그라운드에서 접속이 끊기는 문제를 해결,
> (2) 프로세스 수명은 정확히 전원 ON/OFF로 통제,
> (3) 앱 상단 환경설정 아래에 붉은 전원 버튼,
> (4) 전원 OFF일 때만 전체 프로세스를 완전히 종료,
> (5) 그 외에는 백그라운드에서 계속 대기하고 상대 PTT 시 자동으로 포그라운드로 전화.

**원인 분석**
- 백그라운드 전환 시 앱이 살아 있어도 Android가 CPU를 `Idle`(Doze) 상태로 만들어
  Dart 타이머(PRESENCE 2 s)·UDP 수신이 멈추고, Wi-Fi 멀티캐스트 멤버십도 정지되어
  상대에게 접속이 끊긴 것처럼 보인다. 포그라운드 복귀 시 재접속은 되지만 대기 중 수신이 안 된다.
- 설계상 세션은 백그라운드에서도 유지되도록 되어 있으나(Step 8), 이를 뒷받침할
  **포그라운드 서비스가 없어** OS가 자유롭게 프로세스를 정지/강제 종료할 수 있었다.

**해결 설계**
1. **Android 포그라운드 서비스** `WktkPowerService`(`foregroundServiceType=mediaPlayback`)
   - 앱 시작(전원 ON) 시 `startForeground` → 프로세스 생존 보장 + 상시 알림 표시.
   - 서비스가 `PARTIAL_WAKE_LOCK`(CPU) + `WifiLock`(Wi-Fi 유지) + `MulticastLock`을
     잡아 화면이 꺼져도 소켓 수신·PRESENCE가 계속 동작.
   - 알림 액션: `열기` / `전원 끄기`(서비스 정지 + `Process.killProcess`로 완전 종료).
2. **전원 상태** `WalkieUiState.powerOn`(기본 ON). 앱 기동 = 전원 ON.
   - 전원 ON: 포그라운드 서비스 기동, 백그라운드에서 계속 대기.
   - 전원 OFF: 확인 다이얼로그 → 세션 teardown → 서비스 정지 → **프로세스 완전 종료**.
     (종료 후 재실행하면 전원 ON 상태로 부팅되므로 OFF 상태는 영속화하지 않는다.)
3. **상대 PTT 자동 전화**
   - 백그라운드 상태에서 `remoteStarted` 버스 이벤트 또는 RX 버스트 첫 프레임 감지 시
     (3초 쿨다운) 네이티브 `ring` 호출 → 헤드업 알림 + 진동 + `MainActivity` 기동
     (`FLAG_ACTIVITY_NEW_TASK|SINGLE_TOP`, `launchMode=singleTask`, `taskAffinity` 제거로
     기존 태스크가 확실히 앞으로 올라온다).
   - 포그라운드 복귀 시 `incomingCaller` 로 SnackBar 표시 후 자동 해제.
4. **포그라운드 복귀 처리 변경**: 이전 Step 8은 매 복귀마다 세션을 재기동(teardown→start)했다.
   전원 ON 중에는 세션이 살아 있으므로 **세션이 없을 때만** 재기동하고, 있으면 FGS만 재확인한다.
5. **권한 추가**: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
   `POST_NOTIFICATIONS`, `VIBRATE`, `USE_FULL_SCREEN_INTENT`. 알림 권한은 온보딩에서 함께 요청.
6. **iOS**: 로컬 네트워크 멀티캐스트 entitlement 없이는 백그라운드 UDP 수신이 불가하므로
   본 Step은 Android 한정. iOS는 앱 정면(foreground) 동작 그대로 유지.

**검증 계획**: `flutter analyze` 0건 / `flutter test` (신규 전원·호출 테스트 포함) /
`flutter build apk --debug` / 실기기에서 화면 OFF 상태 PTT 수신 확인.

**검증 결과**: `flutter analyze` 0건, `flutter test` 72/72(신규 `power_test.dart` 5건),
`flutter build apk --debug` 성공. 실기기 2대 E2E(화면 OFF 후 PTT 수신·자동 전화)는 미수행.

**구현 노트**
- `WktkPowerService`(mediaPlayback FGS) + `PowerController`(정적 제어/알림 빌더).
  `setPower(false)` 는 `stopService` 후 250 ms 뒤 `Process.killProcess` → 완전 종료.
  알림 액션 "전원 끄기" 도 동일 경로(`ACTION_POWER_OFF`)를 사용한다.
- `walkie_controller`: `build()` 끝에서 `scheduleMicrotask(_powerOn)` — Notifier `build()`
  안에서 동기 `state=` 는 초기화 전 참조가 된다(이미 알려진 함정).
  `onResume` 은 세션이 없을 때만 재기동(전에는 매번 teardown→start 로 끊김 유발).
- `_maybeCallFromBackground`: `AppLifecycleState` 가 `resumed` 가 아니고
  `remoteStarted` 버스 이벤트 또는 RX 버스트 첫 프레임에서만 발화(쿨다운 3초).
- `WalkieUiState.copyWith` 의 nullable 필드에 `_unset` 센티널 도입 —
  기존 `talkerNickname ?? this.talkerNickname` 때문에 `null` 로 지우기가 불가능했던
  버그(`incomingCaller` 추가와 함께)도 함께 해결했다.
- 함정: 무전기 화면에는 점멸 LED 등 무한 애니메이션이 있어 위젯 테스트의
  `pumpAndSettle` 이 타임아웃한다 → 다이얼로그 전환은 `pump(400 ms)` 로 처리.
- `launchMode=singleTask` + `taskAffinity` 제거: 서비스에서 호출 인텐트를 띄울 때
  기존 태스크가 확실히 앞으로 올라온다(Flutter 템플릿의 빈 affinity는 재사용 불안정).

## 13. 변경 이력

| 일시 | 내용 |
|---|---|
| 2026-09-28 | 최초 작성. D1~D8 확정, 아키텍처·프로토콜·단계별 계획确立. |
| 2026-09-29 | Step 0 완료(도구 설치·검증) · Step 1 완료(UI 뼈대 + APK 빌드). 툴체인 이슈: `sdkmanager`는 명령 후 0xC0000409로 크래시하나 패키지는 정상 설치됨; NDK `30.0.16248370` 명시, permission_handler 요구로 `compileSdk = 37`. `flutter_soloud` build hooks는 MSVC 필수. |
| 2026-09-29 | Step 2 완료(온보딩 권한 + Wi-Fi 감지). 주의: Riverpod `Notifier.build` 내 `ref.listen(...fireImmediately:true)`에서 `state=` 쓰기 시 자기 참조 `Bad state: uninitialized provider` → Notifier는 단순화하고 네트워크 합성은 뷰 모델 `Provider`(walkieUiProvider)로 분리. |
| 2026-09-29 | Step 3 완료(UDP 송수신·Presence). 순수 Dart 계층(packet/codec/subnet/transport/service)으로 `radio_sim` flutter 무의존. 함정: `sendTo`는 채널 포트를 목적지로 사용 → 루프백 같은 포트 공유 시 unicast 배달 비결정적(실기기 무관, 테스트만 port 오버라이드); Windows 브로드캐스트 10013은 소켓 스트림 비동기 오류 → `onError` 흡수. `flutter_tester.exe`·`dart.exe` UDP 방화벽 규칙 추가. analyze 0·테스트 24/24·APK 성공·radio_sim 정상. |
| 2026-09-29 | Step 4 완료(PTT 오디오 경로). PcmSlicer(640 B 절단)·AudioCapture(record startStream)·AudioPlayback(soloud setBufferStream, `init()`/void `deinit()` 확정)·TransceiverService TX_START/TX_END/AUDIO·sendToAllRoutes·onAudio, WalkieController 세션 라이프사이클+PTT+RX(`ref.listen` fireImmediately:false, teardown 시 `ref.mounted` 가드), radio_sim `--tone`+AUDIO 통계, pcm_slicer_test 12건. analyze 0·테스트 36/36·APK 성공. 실기기↔sim 검증은 Step 6. |
| 2026-09-29 | Step 5 완료(지터버퍼·반이중·효과음/햅틱). 순수 Dart `JitterBuffer`(warmup·순서복원·중복폐기·PLC·홀스킵, nowMs 주입)·`ChannelArbiter`(idle/txLocal/rxRemote, 충돌 윈도·양보·guard·타임아웃·자동해제) + 각각 단위 테스트. `service.startTransmit`→Future<bool>, `onBusEvent`(collision/remoteStarted), presence txActive 선인지. VOX(120ms 발화/400ms 침묵)·수신 노이즈 게이트, `SoundEffects`(roger/squelch/denied, `gen_sounds.dart` WAV 생성) + 햅틱 4종(노브 틱 selectionClick 통합). 함정: WAV 4CC LE 역순, 지터 PLC 갭 판정 재설계. analyze 0·테스트 61/61·APK 성공. 다음: Step 6(설정·예외·README·실기기 E2E). |
| 2026-09-29 | Step 6 완료(설정·예외처리·테스트·README). AppPrefs 전 설정 영속화(volume/effects/haptics/vox/noiseGate/themeMode), `ThemeModeController`(다크/라이트/시스템) + main.dart themeMode 연동. WalkieController: `_loadPersistedSettings`+세션 시작 시 재로드, 세터 영속화, `setNickname`(재시작), `restartSession`/`retrySession`, `sessionError` 배너. 설정 화면 재구현(닉네임/기본채널/볼륨/효과음/햅틱/VOX/노이즈게이트/테마/권한), Wi-Fi 배너 '설정' 이동. settings_screen_test 6건(네트워크 스텁 override + 큰 뷰포트). README 작성. 함정: `.valueOrNull` 미존재, RadioGroup API(3.32+), 위젯테스트 pending Timer→override, 뷰포트 잘림. analyze 0·테스트 67/67·APK 성공. 다음: 실기기 2대 E2E(지연/음질 실측). |
| 2026-09-29 | Step 7 완료(접속자 목록·전송 폴백 수정). `DartUdpTransport`에 `broadcastEnabled`(SO_BROADCAST) 적용으로 멀티캐스트 차단 환경(iOS/일부 AP)에서 브로드캐스트 폴백 정상화(접속 대수 0 원인). `Peer`를 `domain/`으로 이동, `WalkieUiState.peers` 추가, `peer_list_sheet.dart` 신규(송신 중 우선 정렬·닉네임/주소 표시). 하단·LCD "접속 N대" 탭으로 목록 열기. analyze 0·테스트 67/67. |
| 2026-09-29 | Step 8 완료(백그라운드 복귀 재접속·접속 확인 버튼). `AppLifecycleListener(onResume)`로 복귀 시 세션 재기동(멀티캐스트 재가입+PRESENCE 재송신). `checkConnection()` 추가, PTT 좌측 상태 텍스트를 '접속 확인' 버튼으로 교체. analyze 0·테스트 67/67·APK 재빌드. |
| 2026-09-29 | Step 9 완료(전원 스위치·백그라운드 유지·상대 PTT 자동 전화). 원인: FGS 부재로 백그라운드에서 CPU 절전+멀티캐스트 정지 → 접속 끊김. 해결: `WktkPowerService`(mediaPlayback FGS, 부분 웨이크락+Wi-Fi 락+멀티캐스트 락, 상시 알림 `열기`/`전원 끄기`), `PowerController`(setPower/ring/isPowerOn, OFF 시 stopService+`Process.killProcess`), `lib/core/platform/power_channel.dart`+`notification_permission.dart`. 상단 환경설정 아래 붉은 `PowerButton` + 전원 OFF 확인 다이얼로그, 백그라운드 PTT 감지 시 헤드업 알림·진동 + 자동 전화(3초 쿨다운) + SnackBar. `onResume` 세션 재기동 → 세션 없을 때만. 권한 5종 추가, `launchMode=singleTask`/`taskAffinity` 제거. copyWith nullable 센티널 버그 수정. analyze 0·테스트 72/72·APK 성공. 다음: 실기기 2대 E2E(화면 OFF 상태 PTT). |
