import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'sessao.dart';
import 'estado.dart';

/* ================================================================== *
 *  ABA CONFIGURAÇÕES
 *  Mostra como o estabelecimento está configurado (taxa de serviço,
 *  formas de pagamento) e as preferências do próprio app.
 *
 *  Os dados do estabelecimento vêm de GET /me e são somente leitura:
 *  quem muda isso é o dono, no painel.
 * ================================================================== */
class TelaConfig extends StatefulWidget {
  const TelaConfig({super.key});

  @override
  State<TelaConfig> createState() => _TelaConfigState();
}

class _TelaConfigState extends State<TelaConfig> {
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
    abaSelecionada.addListener(_aoTrocarAba);
  }

  @override
  void dispose() {
    abaSelecionada.removeListener(_aoTrocarAba);
    super.dispose();
  }

  void _aoTrocarAba() {
    if (abaSelecionada.value == 3 && mounted) _carregar();
  }

  Future<void> _carregar() async {
    if (!apiConfigurada) return;
    setState(() => _carregando = true);
    try {
      final me = await Api.meusDados();
      if (me.isNotEmpty) await Sessao.atualizarGarcom(me);
    } catch (_) {
      // sem internet: mostra o que já está salvo
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String get _destinoTaxa {
    final d = '${Sessao.loja['serviceChargeDestination'] ?? ''}'.toLowerCase();
    switch (d) {
      case 'staff':
        return 'vai para a equipe';
      case 'establishment':
      case 'house':
        return 'fica com a casa';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final taxa = Sessao.taxaServico;

    return RefreshIndicator(
      color: T.redDark,
      onRefresh: _carregar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
            bottom: 130 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HeaderVermelho(child: BarraBoasVindas()),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- taxa de serviço ----------
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: T.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: T.greenSuave,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child:
                                Icon(Ico.conta, size: 24, color: T.green),
                          ),
                          const SizedBox(width: 14),
                          // duas linhas: nome + destino, e a % grande à direita
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Taxa de serviço',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: T.ink,
                                        height: 1.2)),
                                if (taxa > 0 && _destinoTaxa.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(_destinoTaxa,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.25,
                                          color: T.inkSoft)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                              taxa > 0
                                  ? '${taxa.toStringAsFixed(taxa % 1 == 0 ? 0 : 1)}%'
                                  : 'Não cobrada',
                              style: TextStyle(
                                  fontSize: taxa > 0 ? 22 : 14,
                                  fontWeight: FontWeight.w800,
                                  color: taxa > 0 ? T.green : T.inkSoft,
                                  letterSpacing: -.5)),
                          if (_carregando)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: T.tabOff),
                            ),
                        ],
                      ),
                    ),

                    const _Rotulo('Impressora'),
                    const _CartaoImpressora(),

                    const _Rotulo('Preferências'),
                    const _CartaoVisualizacao(),

                    const SizedBox(height: 16),
                    Text(
                      'A taxa de serviço é definida pelo dono no painel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: T.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- pedaços da tela ---------------- */
class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        // mesmo estilo dos títulos de seção da aba Perfil
        padding: const EdgeInsets.fromLTRB(6, 22, 6, 7),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: T.inkSoft)),
      );
}

/* ---------- uma linha compacta, igual aos itens da aba Perfil ---------- */
class _LinhaAjuste extends StatelessWidget {
  final IconData icone;
  final Color cor, fundo;
  final String titulo;
  final String? sub;
  final VoidCallback? onTap;
  final bool carregando;
  const _LinhaAjuste({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    this.sub,
    this.onTap,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: sombraCard(),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fundo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: carregando
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: cor),
                    )
                  : Icon(icone, size: 17, color: cor),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.2,
                          color: T.ink)),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: T.inkSoft)),
                  ],
                ],
              ),
            ),
            Icon(Ico.avancar, size: 20, color: T.fraco),
          ],
        ),
      ),
    );
  }
}

/* ================================================================== *
 *  MODO DE VISUALIZAÇÃO
 *  Uma linha só nos Ajustes. Tocar abre o modal com grade/lista e a
 *  chavinha das 5 mesas por linha.
 * ================================================================== */
class _CartaoVisualizacao extends StatelessWidget {
  const _CartaoVisualizacao();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoLista,
      builder: (_, lista, __) => ValueListenableBuilder<bool>(
        valueListenable: cincoPorLinha,
        builder: (_, cinco, __) => _LinhaAjuste(
          icone: lista ? Ico.lista : Ico.mesas,
          cor: T.azul,
          fundo: T.azulSuave,
          titulo: 'Modo de visualização',
          sub: lista
              ? 'Lista'
              : cinco
                  ? 'Grade · 5 mesas por linha'
                  : 'Grade · 3 mesas por linha',
          onTap: () => _modalDeVisualizacao(context),
        ),
      ),
    );
  }
}

void _modalDeVisualizacao(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (ctx) => Container(
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 18 + MediaQuery.of(ctx).padding.bottom),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: T.borda,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.azulSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Ico.mesas, size: 23, color: T.azul),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo de visualização',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text('Como as mesas aparecem na aba Mesas',
                        style: TextStyle(
                            fontSize: 13, height: 1.25, color: T.inkSoft)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.campo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Ico.fechar, size: 17, color: T.inkMedio),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _EscolhaDeModo(),
          const _CincoPorLinha(),
        ],
      ),
    ),
  );
}

/* ---------------- grade ou lista ---------------- */
class _EscolhaDeModo extends StatelessWidget {
  const _EscolhaDeModo();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoLista,
      builder: (_, lista, __) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: T.campo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.borda),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Opcao(
                icone: Ico.mesas,
                texto: 'Grade',
                ativo: !lista,
                onTap: () => salvarModoDeVer(false),
              ),
            ),
            Expanded(
              child: _Opcao(
                icone: Ico.lista,
                texto: 'Lista',
                ativo: lista,
                onTap: () => salvarModoDeVer(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool ativo;
  final VoidCallback onTap;
  const _Opcao({
    required this.icone,
    required this.texto,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AfundaAoTocar(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativo ? T.card : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: ativo ? T.redDark.withOpacity(.35) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 17, color: ativo ? T.redDark : T.inkSoft),
              const SizedBox(width: 8),
              Text(texto,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ativo ? T.redDark : T.inkSoft)),
            ],
          ),
        ),
      );
}

/* ---------------- 3 ou 5 mesas por linha ---------------- */
class _CincoPorLinha extends StatelessWidget {
  const _CincoPorLinha();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: modoLista,
      builder: (_, lista, __) {
        // só faz sentido no modo grade
        if (lista) return const SizedBox.shrink();

        return ValueListenableBuilder<bool>(
          valueListenable: cincoPorLinha,
          builder: (_, cinco, __) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AfundaAoTocar(
              onTap: () => salvarLarguraDaGrade(!cinco),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: T.campo,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: T.borda),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('5 mesas por linha',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: T.ink,
                                  height: 1.2)),
                          const SizedBox(height: 2),
                          Text(
                              cinco
                                  ? 'Arraste para o lado para ver as outras'
                                  : 'Hoje são 3 por linha',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.25,
                                  color: T.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ToggleMindi(
                      ligado: cinco,
                      aoMudar: (v) => salvarLarguraDaGrade(v),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ---------------- impressora ---------------- */
class _CartaoImpressora extends StatefulWidget {
  const _CartaoImpressora();

  @override
  State<_CartaoImpressora> createState() => _CartaoImpressoraState();
}

class _CartaoImpressoraState extends State<_CartaoImpressora> {
  bool _carregando = true;
  bool _testando = false;

  /// o servidor não sabe responder sobre a impressora
  bool _semRecurso = false;

  bool _ligada = false;
  bool _automatica = false;
  int _quantas = 0;
  String _papel = '';
  String _recado = '';

  @override
  void initState() {
    super.initState();
    _conferir();
  }

  Future<void> _conferir() async {
    if (!apiConfigurada) {
      setState(() => _carregando = false);
      return;
    }
    setState(() {
      _carregando = true;
      _recado = '';
    });
    try {
      final r = await Api.impressora();
      if (!mounted) return;
      setState(() {
        _ligada = r['connected'] == true;
        _automatica = r['autoPrintEnabled'] == true;
        _quantas = r['connections'] is num ? (r['connections'] as num).toInt() : 0;
        _papel = (r['paperWidth'] ?? '').toString();
        _semRecurso = false;
        _carregando = false;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _semRecurso = e.status == 404 || e.codigo == 'NOT_FOUND';
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregando = false);
    }
  }

  Future<void> _testar() async {
    setState(() {
      _testando = true;
      _recado = '';
    });
    try {
      await Api.testarImpressora();
      if (!mounted) return;
      setState(() {
        _testando = false;
        _recado = 'Enviado. Confira se saiu o papel na impressora.';
      });
      _conferir();
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _testando = false;
        if (e.codigo == 'PRINTER_OFFLINE') {
          _recado = 'A impressora não respondeu. '
              'Veja se está ligada e com papel.';
        } else if (e.codigo == 'NO_PRINTABLE_ITEMS') {
          _recado = 'Nada para imprimir: os itens estão marcados '
              'como "não imprimir".';
        } else {
          _recado = e.mensagem;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testando = false;
        _recado = 'Não deu para testar agora. Tente de novo.';
      });
    }
  }

  /// modal com a situação e o botão de imprimir teste
  Future<void> _abrirModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, muda) {
          Future<void> testarAqui() async {
            // dispara o teste e redesenha o modal já com o spinner
            final teste = _testar();
            muda(() {});
            await teste;
            if (ctx.mounted) muda(() {});
          }

          final cor = _semRecurso
              ? T.inkSoft
              : _ligada
                  ? T.green
                  : T.redDark;
          final fundo = _semRecurso
              ? T.campo
              : _ligada
                  ? T.greenSuave
                  : T.redSuave;

          return Container(
            padding: EdgeInsets.fromLTRB(
                18, 20, 18, 18 + MediaQuery.of(ctx).padding.bottom),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: T.borda,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fundo,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child:
                          Icon(Ico.impressora, size: 23, color: cor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_titulo(),
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: T.ink,
                                  height: 1.15,
                                  letterSpacing: -.4)),
                          Text(_detalhe(),
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: T.inkSoft)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: T.campo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Ico.fechar,
                            size: 17, color: T.inkMedio),
                      ),
                    ),
                  ],
                ),
                if (_recado.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(_recado,
                      style: TextStyle(
                          fontSize: 12.5, color: T.inkMedio)),
                ],
                const SizedBox(height: 18),
                AfundaAoTocar(
                  onTap: _testando ? () {} : testarAqui,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.campo,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: T.borda),
                    ),
                    child: _testando
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: T.tabOff),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Ico.impressora,
                                  size: 16, color: T.inkMedio),
                              const SizedBox(width: 8),
                              Text('Imprimir teste',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: T.inkMedio)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    // ao fechar, o card resume a situação mais nova
    if (mounted) setState(() => _recado = '');
  }

  @override
  Widget build(BuildContext context) {
    final cor = _semRecurso
        ? T.inkSoft
        : _ligada
            ? T.green
            : T.redDark;
    final fundo = _semRecurso
        ? T.campo
        : _ligada
            ? T.greenSuave
            : T.redSuave;

    // linha compacta, igual aos itens da aba Perfil;
    // o teste de impressão fica no modal
    return _LinhaAjuste(
      icone: Ico.impressora,
      cor: cor,
      fundo: fundo,
      titulo: _titulo(),
      sub: _detalhe(),
      carregando: _carregando,
      onTap: _abrirModal,
    );
  }

  String _titulo() {
    if (_carregando) return 'Conferindo...';
    if (_semRecurso) return 'Impressora';
    if (!_ligada) return 'Impressora desconectada';
    return _quantas > 1
        ? '$_quantas impressoras conectadas'
        : 'Impressora conectada';
  }

  String _detalhe() {
    if (_semRecurso) {
      return 'Não dá para conferir daqui. Use o teste para ver se sai papel.';
    }
    if (!_ligada) {
      return 'Veja se o computador do balcão está ligado com o Mindi '
          'Printer aberto.';
    }
    return [
      _automatica
          ? 'Impressão automática ligada'
          : 'Impressão automática desligada',
      if (_papel.isNotEmpty) 'papel $_papel',
    ].join(' · ');
  }
}
