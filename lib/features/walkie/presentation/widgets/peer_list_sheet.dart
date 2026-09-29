/// 접속자 목록 시트.
///
/// LCD/하단의 "접속 N대"를 탭하면 같은 채널에 접속 중인 기기와
/// 닉네임·주소·송신 여부를 보여준다.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/peer.dart';

Future<void> showPeerListSheet(
  BuildContext context, {
  required List<Peer> peers,
  required String localNickname,
  required int channel,
}) {
  final sorted = List<Peer>.of(peers)
    ..sort((a, b) {
      if (a.txActive != b.txActive) return a.txActive ? -1 : 1;
      return a.nickname.compareTo(b.nickname);
    });

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '접속자',
                    style: TextStyle(
                      color: AppColors.textHi,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sorted.length}대',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'CH ${channel.toString().padLeft(2, '0')} · 나는 $localNickname',
                style: const TextStyle(color: AppColors.textLow, fontSize: 11),
              ),
              const SizedBox(height: 12),
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.wifi_tethering_off,
                          color: AppColors.textLow,
                          size: 34,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '같은 채널에 접속한 기기가 없습니다',
                          style: TextStyle(
                            color: AppColors.textMid,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '상대도 같은 Wi-Fi에서 같은 채널로 실행 중인지 확인하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLow,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.surfaceHigh),
                    itemBuilder: (context, i) => _PeerTile(peer: sorted[i]),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final talking = peer.txActive;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: talking ? AppColors.accentSoft : AppColors.surfaceHigh,
        child: Icon(
          talking ? Icons.record_voice_over : Icons.person_outline,
          color: talking ? AppColors.accent : AppColors.textMid,
          size: 20,
        ),
      ),
      title: Text(
        peer.nickname.isEmpty ? '알 수 없음' : peer.nickname,
        style: const TextStyle(
          color: AppColors.textHi,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${peer.address}:${peer.port}',
        style: const TextStyle(
          color: AppColors.textLow,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
      trailing: talking
          ? const Text(
              '송신 중',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
