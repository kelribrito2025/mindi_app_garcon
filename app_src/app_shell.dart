import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tema.dart';
import 'estado.dart';
import 'tab_bar_curva.dart';
import 'atualizacao.dart';
import 'tela_mesas.dart';
import 'tela_ganhos.dart';
import 'tela_alertas.dart';
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
    TelaAlertas(),
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

  /// o voltar do Android na raiz das abas: pergunta antes de sair.
  /// (Nas telas internas, que ficam por cima, o voltar só volta —
  /// esta pergunta nem chega a aparecer.)
  Future<void> _confirmarSaida() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: T.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: T.borda,
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Text('Deseja sair?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: T.ink)),
              const SizedBox(height: 6),
              Text('O app vai fechar. Você continua conectado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: T.inkSoft)),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // fecha o app, mas ele continua no gerenciador
                    // de tarefas (não é um encerramento forçado)
                    SystemNavigator.pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: T.redDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Sim, sair',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: T.inkMedio)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // altura da barra de navegação do Android
    final margemInferior = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (jaSaiu, _) {
        if (jaSaiu) return;
        _confirmarSaida();
      },
      child: Scaffold(
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
      ),
    );
  }
}
