import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/* ================================================================== *
 *  ALERTA DE PEDIDO NOVO
 *  Faz o celular vibrar forte. Fica num arquivo só para poder ser
 *  chamado de qualquer tela (Início, notificação, botão de teste).
 * ================================================================== */

/// evita vibrar várias vezes seguidas se chegarem 2 avisos juntos
DateTime? _ultimoAlerta;

/// Diz que o entregador JÁ foi avisado agora (por exemplo, a notificação
/// do sistema acabou de tocar e vibrar). Assim a tela não vibra de novo
/// alguns segundos depois, quando a lista de pedidos é atualizada.
void marcarAlertaFeito() => _ultimoAlerta = DateTime.now();

Future<void> alertarPedidoNovo({bool forcar = false}) async {
  final agora = DateTime.now();
  if (!forcar &&
      _ultimoAlerta != null &&
      agora.difference(_ultimoAlerta!).inSeconds < 5) {
    return;
  }
  _ultimoAlerta = agora;

  // 1) vibração de verdade (motor do celular): 3 pulsos longos
  try {
    final tem = await Vibration.hasVibrator();
    if (tem == true) {
      await Vibration.vibrate(pattern: [0, 600, 250, 600, 250, 800]);
      return;
    }
  } catch (_) {
    // sem suporte ou erro no plugin: usa o plano B
  }

  // 2) plano B: o toque curto do próprio sistema
  for (var i = 0; i < 4; i++) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
