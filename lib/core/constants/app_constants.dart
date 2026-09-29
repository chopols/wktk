/// 앱 전역 상수 정의.
///
/// 프로토콜/타이밍 상수는 반드시 이 파일에 두고 다른 파일에서는 참조만 한다.
library;

abstract final class AppConstants {
  // ── 프로토콜 ────────────────────────────────────────────
  /// 패킷 매직 넘버 ('WK')
  static const int kMagic = 0x4B57;

  /// 프로토콜 버전
  static const int kProtocolVersion = 1;

  /// 채널별 포트 베이스 (포트 = kBasePort + 채널번호)
  static const int kBasePort = 45000;

  /// 멀티캐스트 그룹 프리픽스 (그룹 = 239.255.42.<채널>)
  static const String kMulticastPrefix = '239.255.42';

  /// UDP 데이터그램 최대 길이 (오디오 640B + 헤더 + 여유)
  static const int kMaxDatagramBytes = 1200;

  /// 브로드캐스트 기본 주소
  static const String kBroadcastAddress = '255.255.255.255';

  // ── 오디오 ──────────────────────────────────────────────
  static const int kSampleRate = 16000;
  static const int kChannels = 1;
  static const int kBytesPerSample = 2;

  /// 20ms 프레임 = 320 샘플 = 640 바이트
  static const int kFrameMs = 20;
  static const int kFrameSamples = 320;
  static const int kFrameBytes = 640;

  // ── 타이밍 ──────────────────────────────────────────────
  /// PRESENCE 송신 주기
  static const Duration kPresenceInterval = Duration(milliseconds: 2000);

  /// 접속자 만료 시간
  static const Duration kPeerTimeout = Duration(seconds: 8);

  /// 지터 버퍼 목표 지연
  static const Duration kJitterBuffer = Duration(milliseconds: 60);

  /// 수신 프레임이 이 시간 이상 도착해도 재생하지 않을 시간(버퍼 오버플로우 한계)
  static const int kJitterBufferFlushDropGap = 120;

  /// TX 중 오디오가 이 시간 이상 없으면 버스 점유 해제
  static const Duration kTxIdleTimeout = Duration(milliseconds: 400);

  /// TX_END 후 버스 유지 시간(테일 컷 방지)
  static const Duration kTxGuard = Duration(milliseconds: 250);

  /// 이 시간 이상 수신 프레임이 없으면 RX 종료
  static const Duration kRxIdleTimeout = Duration(milliseconds: 1200);

  /// 충돌 판정 윈도우
  static const Duration kCollisionWindow = Duration(milliseconds: 250);

  // ── VOX / 노이즈 게이트 ─────────────────────────────────
  /// VOX 발화 감지 임계(RMS 0.0~1.0)
  static const double kVoxEngageThreshold = 0.04;

  /// VOX 종료 임계(발화 감지보다 낮아야 함)
  static const double kVoxReleaseThreshold = 0.02;

  /// VOX 발화 판정 유지 시간
  static const int kVoxEngageMs = 120;

  /// VOX 종료 판정 유지 시간
  static const int kVoxReleaseMs = 400;

  /// 수신 노이즈 게이트 임계(RMS, 미만이면 침묵 처리)
  static const double kNoiseGateThreshold = 0.01;

  // ── UI 기본값 ───────────────────────────────────────────
  static const double kDefaultVolume = 0.7;
  static const int kDefaultChannel = 1;
  static const int kChannelCount = 16;
  static const int kMaxNicknameChars = 12;

  // ── 백그라운드 대기 / 호출 ────────────────────────────────
  /// 백그라운드 대기 중 상대 PTT 감지 시 같은 발화 연속으로 중복 전화하지 않도록 하는 쿨다운
  static const Duration kIncomingCallCooldown = Duration(seconds: 3);

  // ── 암호화 확장 포인트 ──────────────────────────────────
  // 현재 단계에서 암호화 없음. 확장 시:
  //  - 패킷 flags bit0(crypt) = 1
  //  - baseHeader 뒤에 nonce(12B) + authTag(16B) 삽입
  //  - payload는 ChaCha20-Poly1305로 암호화
  //  Wire 호환을 유지하기 위해 여기서는 0으로 고정한다.
  static const bool kEncryptionEnabled = false;
}
