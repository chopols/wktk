/// 무전기 UI 상태 모델 (도메인).
library;

import 'package:flutter/foundation.dart';

import '../../../core/network/network_monitor.dart' show NetKind;
import 'peer.dart';

enum TxStatus { idle, transmitting, receiving, busy, collision }

/// `copyWith`에서 "값을 그대로 둔다"와 "null 로 지운다"를 구분하기 위한 표시자.
const Object _unset = Object();

@immutable
class WalkieUiState {
  const WalkieUiState({
    this.channel = 1,
    this.volume = 0.7,
    this.txStatus = TxStatus.idle,
    this.wifiOk = true,
    this.netKind = NetKind.unknown,
    this.peerCount = 0,
    this.peers = const <Peer>[],
    this.talkerNickname,
    this.localNickname = '나',
    this.signalLevel = 0.0,
    this.channelBusy = false,
    this.effectsEnabled = true,
    this.hapticsEnabled = true,
    this.voxEnabled = false,
    this.noiseGateEnabled = true,
    this.sessionError,
    this.powerOn = true,
    this.incomingCaller,
  });

  final int channel;
  final double volume; // 0.0 ~ 1.0
  final TxStatus txStatus;
  final bool wifiOk;
  final NetKind netKind;
  final int peerCount;
  final List<Peer> peers; // 같은 채널 접속자 목록 (LCD 접속대수 탭 시 표시)
  final String? talkerNickname; // RX 중 송신자 닉네임
  final String localNickname;
  final double signalLevel; // 0.0 ~ 1.0 (레벨 미터)
  final bool channelBusy; // 반이중: 다른 사용자 송신 중
  final bool effectsEnabled;
  final bool hapticsEnabled;
  final bool voxEnabled; // VOX 모드 토글 (설정)
  final bool noiseGateEnabled; // 수신 노이즈 게이트 토글 (설정)
  final String? sessionError; // 세션(소켓/오디오) 시작 실패 메시지
  final bool powerOn; // 전원 ON = 백그라운드 대기(포그라운드 서비스) 가동
  final String? incomingCaller; // 백그라운드 대기 중 전화를 걸어 온 발화자

  static const WalkieUiState initial = WalkieUiState();

  WalkieUiState copyWith({
    int? channel,
    double? volume,
    TxStatus? txStatus,
    bool? wifiOk,
    NetKind? netKind,
    int? peerCount,
    List<Peer>? peers,
    Object? talkerNickname = _unset,
    String? localNickname,
    double? signalLevel,
    bool? channelBusy,
    bool? effectsEnabled,
    bool? hapticsEnabled,
    bool? voxEnabled,
    bool? noiseGateEnabled,
    Object? sessionError = _unset,
    bool? powerOn,
    Object? incomingCaller = _unset,
  }) {
    return WalkieUiState(
      channel: channel ?? this.channel,
      volume: volume ?? this.volume,
      txStatus: txStatus ?? this.txStatus,
      wifiOk: wifiOk ?? this.wifiOk,
      netKind: netKind ?? this.netKind,
      peerCount: peerCount ?? this.peerCount,
      peers: peers ?? this.peers,
      talkerNickname: identical(talkerNickname, _unset)
          ? this.talkerNickname
          : talkerNickname as String?,
      localNickname: localNickname ?? this.localNickname,
      signalLevel: signalLevel ?? this.signalLevel,
      channelBusy: channelBusy ?? this.channelBusy,
      effectsEnabled: effectsEnabled ?? this.effectsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      voxEnabled: voxEnabled ?? this.voxEnabled,
      noiseGateEnabled: noiseGateEnabled ?? this.noiseGateEnabled,
      sessionError: identical(sessionError, _unset)
          ? this.sessionError
          : sessionError as String?,
      powerOn: powerOn ?? this.powerOn,
      incomingCaller: identical(incomingCaller, _unset)
          ? this.incomingCaller
          : incomingCaller as String?,
    );
  }
}

/// 화면 분기용 상태 (예약).
enum AppScreen { onboarding, walkie }
