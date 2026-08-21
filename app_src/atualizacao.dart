import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'tema.dart';
import 'icones.dart';

/* ================================================================== *
 *  ATUALIZAÇÃO PELO AR (Shorebird)
 *
 *  Como funciona: quando mandamos uma correção, o app BAIXA ela em
 *  segundo plano enquanto está sendo usado, mas só passa a valer no
 *  próximo arranque — não dá para trocar o código com a tela aberta.
 *
 *  Sem aviso nenhum, o usuário precisa fechar e abrir "sem motivo".
 *  Este arquivo avisa na tela que a correção já está pronta e oferece
 *  um botão para fechar o app na hora.
 * ================================================================== */

/// Versão que aparece no Perfil. Precisa bater com a linha `version:`
/// do pubspec.yaml — o Shorebird só aplica correção feita para ela.
const String kVersaoDoApp = '1.0.0+6';

/// vira true quando existe correção baixada esperando o próximo arranque
final atualizacaoPronta = ValueNotifier<bool>(false);

/// número da correção que está rodando agora (null = nenhuma ainda).
/// Serve para o garçom saber se o celular dele já pegou o conserto.
final correcaoAtual = ValueNotifier<int?>(null);

/// Lê qual correção está valendo neste momento.
Future<void> lerCorrecaoAtual() async {
  try {
    final atual = await ShorebirdUpdater().readCurrentPatch();
    correcaoAtual.value = atual?.number;
  } catch (_) {
    correcaoAtual.value = null;
  }
}

/// Procura correção e baixa. Nunca lança erro: se não houver internet,
/// se o app não tiver Shorebird (modo de teste), tudo segue igual.
Future<void> procurarAtualizacao() async {
  await lerCorrecaoAtual();
  try {
    final atualizador = ShorebirdUpdater();
    final situacao = await atualizador.checkForUpdate();

    switch (situacao) {
      case UpdateStatus.restartRequired:
        // já tinha sido baixada numa sessão anterior
        atualizacaoPronta.value = true;
        return;
      case UpdateStatus.outdated:
        await atualizador.update();
        atualizacaoPronta.value = true;
        return;
      case UpdateStatus.upToDate:
        return;
      default:
        return; // já está na última versão, ou o app não usa Shorebird
    }
  } catch (_) {
    // sem internet ou servidor fora: tenta de novo no próximo arranque
  }
}

/* ---------------- vigia: procura de novo de tempos em tempos ----------------
   O garçom fica com o app aberto o turno inteiro. Sem isso, uma correção
   publicada depois da abertura só seria notada no próximo arranque.     */
class VigiaDeAtualizacao extends StatefulWidget {
  final Widget child;
  const VigiaDeAtualizacao({super.key, required this.child});

  @override
  State<VigiaDeAtualizacao> createState() => _VigiaDeAtualizacaoState();
}

class _VigiaDeAtualizacaoState extends State<VigiaDeAtualizacao>
    with WidgetsBindingObserver {
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // com o app aberto, confere a cada 15 minutos
    _relogio = Timer.periodic(
        const Duration(minutes: 15), (_) => procurarAtualizacao());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // voltou para a frente (trocou de app e voltou): confere na hora
    if (estado == AppLifecycleState.resumed) procurarAtualizacao();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/* ---------------- a faixa que aparece na tela ---------------- */
class AvisoDeAtualizacao extends StatelessWidget {
  const AvisoDeAtualizacao({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: atualizacaoPronta,
      builder: (context, pronta, _) {
        if (!pronta) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 11, 11),
            decoration: BoxDecoration(
              color: T.dark2,
              borderRadius: BorderRadius.circular(16),
              boxShadow: sombraCard(opacidade: .18, blur: 18, y: 6),
            ),
            child: Row(
              children: [
                Icon(Ico.baixar, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Atualização pronta',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2)),
                      Text('Feche e abra o app para aplicar',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.25,
                              color: Colors.white.withOpacity(.75))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AfundaAoTocar(
                  // encerra o processo DE VERDADE: o SystemNavigator.pop
                  // só esconde o app e o Android o mantém vivo — ao voltar,
                  // a correção não entrava. Com exit(0) o próximo toque no
                  // ícone abre o app do zero, já corrigido.
                  onTap: () => exit(0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text('Fechar',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: T.dark2)),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => atualizacaoPronta.value = false,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Ico.fechar,
                        size: 15, color: Colors.white.withOpacity(.7)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
