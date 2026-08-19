import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play 인앱 업데이트로 새 버전 여부를 '자동 감지'해요.
///
/// - 앱이 Play(내부/폐쇄/공개/프로덕션 트랙)로 설치된 경우, Play가 더 새로운
///   빌드가 트랙에 올라와 있는지 직접 알려줘요. 그래서 Firestore 같은 별도
///   서버 값(버전 번호)을 사람이 매번 올릴 필요가 전혀 없어요.
/// - 새 빌드를 트랙에 올리기만 하면, 구버전을 쓰는 테스터 앱이 켜질 때
///   자동으로 감지해서 아래 안내 팝업을 띄워요.
/// - 단, Play로 설치된 앱에서만 동작해요. 로컬 사이드로드/디버그(flutter run)로
///   설치한 앱에서는 Play가 버전 정보를 모르므로 뜨지 않아요(정상이에요).
enum UpdateStatus { none, available }

class AppUpdateGate {
  /// 새 버전이 트랙에 올라와 있으면 available을 반환해요.
  static Future<UpdateStatus> check() async {
    if (kIsWeb) return UpdateStatus.none;
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable
          ? UpdateStatus.available
          : UpdateStatus.none;
    } catch (_) {
      // Play 설치가 아니거나 점검 실패 시 앱 사용을 막지 않아요.
      return UpdateStatus.none;
    }
  }

  /// 업데이트 안내 흐름:
  /// 1) "업데이트가 있어요. 지금 업데이트하시겠어요?" → 예/아니오
  /// 2) 예 → Play 인앱 업데이트 실행(업데이트 화면으로 이동)
  /// 3) 아니오 → 미업데이트 시 생길 수 있는 불편 안내 → '동의하고 닫기' → 그대로 유지
  static Future<void> promptUpdate(BuildContext context) async {
    final wantUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 예/아니오 중 하나는 반드시 선택하도록.
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        title: Row(
          children: [
            Image.asset('assets/image/image/main_duck.png', width: 40, height: 40, fit: BoxFit.contain),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('업데이트가 있어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
            ),
          ],
        ),
        content: const Text(
          '더 편해진 덕옥션 새 버전이 나왔어요.\n지금 업데이트하시겠어요?',
          style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF94A3B8)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6F91)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );

    if (wantUpdate == true) {
      await _runUpdate();
      return;
    }

    // 아니오 → 미업데이트 시 불편 안내 후 '동의하고 닫기'.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('업데이트를 미루시겠어요?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF16305C))),
            ),
          ],
        ),
        content: const Text(
          '최신 버전이 아니면 일부 기능이 정상적으로 동작하지 않거나, 오류·이용 불편이 생길 수 있어요. '
          '더 편하고 안정적인 이용을 위해 되도록 빨리 업데이트해 주세요.\n\n'
          '위 내용을 확인했으며, 지금은 업데이트하지 않고 계속 이용할게요.',
          style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF475569)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF334155)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('동의하고 닫기'),
          ),
        ],
      ),
    );
  }

  static Future<void> _runUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      } else {
        // 둘 다 허용값이 안 오면(정보 지연 등) 즉시 업데이트를 한 번 시도해요.
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // 업데이트 실행 실패 시 조용히 넘어가요(다음 실행 때 다시 안내).
    }
  }
}
