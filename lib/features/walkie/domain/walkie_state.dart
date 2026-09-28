/// 무전기 UI 상태 모델 (도메인).
library;

import 'package:flutter/foundation.dart';

import '../../../core/network/network_monitor.dart' show NetKind;

enum TxStatus { idle, transmitting, receiving, busy, collision }

@immutable
class WalkieUiState {
  const WalkieUiState({
    this.channel = 1,
    this.volume = 0.7,
    this.txStatus = TxStatus.idle,
    this.wifiOk = true,
    this.netKind = NetKind.unknown,
    this.peerCount = 0,
    this.talkerNickname,
    this.localNickname = '나',
    this.signalLevel = 0.0,
    this.channelBusy = false,
    this.effectsEnabled = true,
    this.hapticsEnabled = true,
    this.voxEnabled = false,
    this.noiseGateEnabled = true,
    this.sessionError,
  });

  final int channel;
  final double volume; // 0.0 ~ 1.0
  final TxStatus txStatus;
  final bool wifiOk;
  final NetKind netKind;
  final int peerCount;
  final String? talkerNickname; // RX 중 송신자 닉네임
  final String localNickname;
  final double signalLevel; // 0.0 ~ 1.0 (레벨 미터)
  final bool channelBusy; // 반이중: 다른 사용자 송신 중
  final bool effectsEnabled;
  final bool hapticsEnabled;
  final bool voxEnabled; // VOX 모드 토글 (설정)
  final bool noiseGateEnabled; // 수신 노이즈 게이트 토글 (설정)
  final String? sessionError; // 세션(소켓/오디오) 시작 실패 메시지

  static const WalkieUiState initial = WalkieUiState();

  WalkieUiState copyWith({
    int? channel,
    double? volume,
    TxStatus? txStatus,
    bool? wifiOk,
    NetKind? netKind,
    int? peerCount,
    String? talkerNickname,
    String? localNickname,
    double? signalLevel,
    bool? channelBusy,
    bool? effectsEnabled,
    bool? hapticsEnabled,
    bool? voxEnabled,
    bool? noiseGateEnabled,
    String? sessionError,
  }) {
    return WalkieUiState(
      channel: channel ?? this.channel,
      volume: volume ?? this.volume,
      txStatus: txStatus ?? this.txStatus,
      wifiOk: wifiOk ?? this.wifiOk,
      netKind: netKind ?? this.netKind,
      peerCount: peerCount ?? this.peerCount,
      talkerNickname: talkerNickname ?? this.talkerNickname,
      localNickname: localNickname ?? this.localNickname,
      signalLevel: signalLevel ?? this.signalLevel,
      channelBusy: channelBusy ?? this.channelBusy,
      effectsEnabled: effectsEnabled ?? this.effectsEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      voxEnabled: voxEnabled ?? this.voxEnabled,
      noiseGateEnabled: noiseGateEnabled ?? this.noiseGateEnabled,
      sessionError: sessionError ?? this.sessionError,
    );
  }
}

/// 화면 분기용 상태 (예약).
enum AppScreen { onboarding, walkie }
