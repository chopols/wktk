# WKTK — 서버 없는 Wi-Fi 워키토키 (Walkie-talkie)

같은 Wi-Fi(LAN)에 있는 기기끼리 **서버 없이** PTT(누르고 말하기) 무전기처럼
음성을 주고받는 Flutter 앱. 멀티캐스트 UDP로 직접 통신하며, 오디오는
16 kHz Mono 16-bit PCM을 20 ms 프레임으로 잘라 실시간 전송한다.

## 기능

- **PTT 송수신**: 큰 버튼을 누르고 말하기. 반이중 규칙을 자동으로 지킨다.
- **반이중 중재**: 채널 사용 중이면 시작 거부(거부음 + busy 표시), 동시 발화는
  충돌 감지, 마지막 발화자가 끝난 뒤(guard 250 ms) 재송신 허용.
- **채널/볼륨 노브**: 16채널 선택(노치 틱 햅틱), 볼륨 조절.
- **VOX**: 손 없이 목소리로 자동 송신(발화 감지 120 ms / 종료 400 ms).
- **수신 노이즈 게이트**: 작은 잡음 프레임을 침묵 처리.
- **지터 버퍼 + PLC**: 순서 복원·중복 폐기·유실 구간 보정, 재생 안정화.
- **효과음/햅틱**: roger beep(송신 시작/끝), 스퀠치, 거부음 + PTT/노브/거부 햅틱.
- **접속자 표시(LCD)**: 같은 채널의 상대 수, 발화자 이름, 신호 레벨 미터.
  접속 대수를 탭하면 접속 중인 닉네임·주소 목록을 확인할 수 있다.
- **설정**: 닉네임, 기본 채널, 재생 볼륨, 효과음/햅틱/VOX/노이즈 게이트, 테마
  (다크/라이트/시스템) 영속화.

## 빌드·설치

### 요구 사항
- Flutter 3.13+ (Dart 3.4+), Android SDK (minSdk 24+)
- Android 6.0+ 실기기 2대 이상 (Android 에뮬레이터는 멀티캐스트 미지원으로 부적합)

### 실행
```bash
flutter pub get
flutter run            # 연결된 기기에서 실행
flutter build apk --debug
# APK: build/app/outputs/flutter-apk/app-debug.apk
```

### Android 권한 (AndroidManifest.xml)
`INTERNET`, `RECORD_AUDIO`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
(멀티캐스트 락), `ACCESS_NETWORK_STATE`, `WAKE_LOCK`(화면 잠금 유지).

### iOS 권한 (Info.plist) — 미검증
`NSMicrophoneUsageDescription`, `NSLocalNetworkUsageDescription` 선언 완료.
다만 **iOS에서의 멀티캐스트 수신·백그라운드는 미검증**이며, 멀티캐스트 락이
없어 배포 전 실기기 확인이 필요하다. (Android 우선 개발)

## 사용법 (2대 실기기 절차)

1. 두 기기를 **같은 Wi-Fi(LAN)**에 연결한다. (AP가 클라이언트 간 격리
   "AP Isolation"을 켜면 안 됨)
2. 양쪽 모두 첫 실행에서 마이크 권한을 허용한다.
3. 설정 → **기본 채널**을 같은 번호로 맞춘다. (1~16)
4. LCD에 상대의 **접속 N대**가 뜨면 준비 완료.
5. A가 PTT를 누른 채 말하면 B에게 들리고, LCD에 발화자 이름·신호 레벨이 표시된다.
6. 통화 중 B가 PTT를 누르면 **채널 사용 중** 배너 + 거부음.
7. 테스트 이후 **설정 → 닉네임/볼륨/효과음**을 원하는 대로 바꾼다.

### 체크리스트
- [ ] 두 기기 모두 같은 Wi-Fi (비교적 저지연, RTT ~10 ms 이하 권장)
- [ ] 마이크 권한 허용, 시스템 소리로 재생 (기기 소리가 켜져 있어야 함)
- [ ] 같은 채널 번호
- [ ] Wi-Fi AP가 기기 간 통신을 허용하는지 (게스트 네트워크는 종종 격리됨)
- [ ] 발화가 짧게 끊기는 경우: 지터 버퍼(60 ms)·네트워크 상태 확인

## radio_sim (PC 시뮬레이터)

순수 Dart로 앱과 같은 프로토콜을 쓰는 CLI. Windows에서 `dart run`으로 실행하고,
방화벽에서 dart.exe의 개인 네트워크 UDP를 허용하면 실기기와 통신할 수 있다.

```bash
dart run tool/radio_sim.dart --channel 1 --nick sim-pc          # 접속 + 통계
dart run tool/radio_sim.dart --channel 1 --nick sim-pc --tone   # 테스트 톤 반복
dart run tool/radio_sim.dart --channel 1 --nick sim-pc --once   # PRESENCE 1회 후 종료
```

옵션: `--channel N(1~16)`, `--nick 이름`, `--tone`(PTT 자동 발화 + 440 Hz 톤),
`--ticks`(초당 프레임, 기본 50), `--once`(1회 프레즌스 후 종료).

효과음 WAV는 `tool/gen_sounds.dart`로 다시 생성할 수 있다:
```bash
dart run tool/gen_sounds.dart    # assets/sounds/*.wav (44.1k mono 16-bit)
```

## 아키텍처

```
lib/
├─ app/            # 테마(다크/라이트), 라우터(AppGate: 온보딩 ↔ 무전기)
├─ core/
│  ├─ constants/   # 프로토콜·타이밍 상수 (AppConstants)
│  ├─ network/     # packet/packet_codec, subnet, transport(UDP), network_monitor(Riverpod)
│  └─ utils/       # AppPrefs (shared_preferences 영속 설정)
└─ features/
   ├─ onboarding/  # 첫 실행 권한 요청
   ├─ settings/    # 설정 화면 + 테마 컨트롤러
   └─ walkie/
      ├─ domain/   # WalkieUiState (Riverpod Notifier 상태)
      ├─ data/     # TransceiverService, PeerRegistry, ChannelArbiter,
      │            # JitterBuffer, audio/(AudioCapture·AudioPlayback·SoundEffects·PcmSlicer)
      └─ presentation/  # WalkieController(오케스트레이션), WalkieScreen + 위젯(LCD·PTT·노브…)
```

**순수 Dart 경계**: `core/network/**`, `features/walkie/data/**`,
`tool/radio_sim.dart`는 Flutter에 의존하지 않는다(플러그인·플랫폼 채널 없음).
SoLoud/record 등 플러그인 사용은 앱 쪽(presentation, audio)에만 있다.

## 프로토콜 (v1)

- **전송**: 채널별 포트 `45000 + 채널`, 멀티캐스트 `239.255.42.<채널>` + 브로드캐스트
  `255.255.255.255` + 학습된 상대 유니캐스트 3경로로 전송(자기 패킷은 senderId로 폐기).
  원활한 멀티캐스트 수신을 위해 Android에서 멀티캐스트 락 사용.
- **헤더 (40 Byte, little-endian)**:
  `magic(0x4B57) u16 | ver u8 | type u8 | flags u8 | headerLen u8 | payloadLen u16 |
   seq u32 | channel u8 | codec u8 | sampleRate u16 | timestampMs u64 | senderId(16 B)`
- **타입**:
  | type | body | 용도 |
  |------|------|------|
  | presence(0) | nickLen·nick·txActive | 2초 주기, 8초 미접속 시 만료 (txActive=상대 송신 선인지) |
  | txStart(1) | nickLen·nick·talkMs | 발화 시작 (중재 판정) |
  | txEnd(2) | nickLen·nick | 발화 종료 |
  | audio(3) | 640 B PCM (16 kHz/16bit/모노 20 ms) | 음성 프레임 |

- **반이중 중재**: collisionWindow 250 ms 내 동시 발화 = 충돌(로컬 중단 + 배너),
  이후 발화 = 상대 우선(양보). guard 250 ms 후 버스 해제, rxIdle 1200 ms,
  txIdle 400 ms 오디오 없으면 자동 해제.
- **암호화**: 현재 없음(확장 포인트만 상수로 예약). 사설 네트워크용.

## 테스트

```bash
flutter analyze    # 0 issues
flutter test       # 67 tests
```

- 순수 Dart 단위 테스트: packet_codec, peer_registry, pcm_slicer, jitter_buffer,
  channel_arbiter (모두 결정성 클록 주입).
- 위젯 테스트: 온보딩/무전기 분기, 설정 화면(닉네임 저장·토글·테마·기본 채널).
- UDP 루프백 통합: DartUdpTransport 멀티캐스트/브로드캐스트/유니캐스트.
- WAV 자산 검증: 효과음 헤더(RIFF/WAVE/PCM/mono/44.1k/16bit).

## 문서

- `documents/IMPLEMENT.md` — 0~6 단계 계획과 상세 설계·변경 이력
- `documents/TASKS_EXECUTED.md` — 작업 로그