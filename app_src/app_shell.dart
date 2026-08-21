import 'package:flutter/material.dart';
import 'tema.dart';
import 'estado.dart';
import 'tab_bar_curva.dart';
import 'atualizacao.dart';
import 'tela_mesas.dart';
import 'tela_ganhos.dart';
import 'tela_config.dart';
import 'tela_perfil.dart';
import 'tela_login.dart';

/* ================================================================== *
 *  ESQUELETO DO APP — segura as 3 telas + a tab bar
 *  Para adicionar uma tela nova:
 *    1. crie o arquivo tela_xxx.dart
 *    2. importe aqui em cima
 *    3. adicione na lista _telas abaixo
 *    4. adicione o item correspondente em kAbas (tab_bar_curva.dart)
 * ================================================================== */
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<Widget> _telas = const [
    TelaMesas(),
    TelaGanhos(),
    TelaConfig(),
    TelaPerfil(),
  ];

  @override
  void initState() {
    super.initState();
    sessaoEncerrada.addListener(_aoEncerrarSessao);
  }

  @override
  void dispose() {
    sessaoEncerrada.removeListener(_aoEncerrarSessao);
    super.dispose();
  }

  /// o servidor avisou que a conta foi removida, desativada ou perdeu
  /// a permissão: volta para o login e explica o motivo
  void _aoEncerrarSessao() {
    final motivo = sessaoEncerrada.value;
    if (motivo == null || !mounted) return;
    sessaoEncerrada.value = null;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
      (rota) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(motivo),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.dark2,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // altura da barra de navegação do Android
    final margemInferior = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: T.bg,
      // o vigia procura correção quando o app volta para a frente
      // e a cada 15 minutos com ele aberto
      body: VigiaDeAtualizacao(
        child: Stack(
        children: [
          // IndexedStack mantém o estado de cada tela ao trocar de aba
          ValueListenableBuilder<int>(
            valueListenable: abaSelecionada,
            builder: (_, aba, __) =>
                IndexedStack(index: aba, children: _telas),
          ),
          Positioned(
            left: kSide,
            right: kSide,
            bottom: margemInferior + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // faixa "Atualização pronta" logo acima da barra de abas
                const AvisoDeAtualizacao(),
                ValueListenableBuilder<int>(
                  valueListenable: abaSelecionada,
                  builder: (_, aba, __) => TabBarCurva(
                    indice: aba,
                    aoTrocar: (i) => abaSelecionada.value = i,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
