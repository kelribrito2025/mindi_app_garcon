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
    if (abaSelecionada.value == 2 && mounted) _carregar();
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Taxa de serviço',
                                    style: TextStyle(
                                        fontSize: 13, color: T.inkSoft)),
                                const SizedBox(height: 2),
                                Text(
                                    taxa > 0
                                        ? '${taxa.toStringAsFixed(taxa % 1 == 0 ? 0 : 1)}%'
                                        : 'Não cobrada',
                                    style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: T.ink,
                                        letterSpacing: -.5)),
                                if (taxa > 0 && _destinoTaxa.isNotEmpty)
                                  Text(_destinoTaxa,
                                      style: TextStyle(
                                          fontSize: 12.5, color: T.inkSoft)),
                              ],
                            ),
                          ),
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

                    const _Rotulo('IMPRESSORA'),
                    const _CartaoImpressora(),

                    const _Rotulo('PREFERÊNCIAS'),
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
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 9),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
                color: T.inkSoft)),
      );
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
        builder: (_, cinco, __) => AfundaAoTocar(
          onTap: () => _modalDeVisualizacao(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.azulSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(lista ? Ico.lista : Ico.mesas,
                      size: 21, color: T.azul),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modo de visualização',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: T.ink,
                              height: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                          lista
                              ? 'Lista'
                              : cinco
                                  ? 'Grade · 5 mesas por linha'
                                  : 'Grade · 3 mesas por linha',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.25,
                              color: T.inkSoft)),
                    ],
                  ),
                ),
                Icon(Ico.avancar, size: 20, color: T.fraco),
              ],
            ),
          ),
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
  String _nome = '';
  String _ultimoErro = '';
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
        _ligada = r['online'] == true;
        _automatica = r['autoPrint'] == true;
        _nome = (r['name'] ?? '').toString();
        _ultimoErro = (r['lastError'] ?? '').toString();
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
        _recado = e.codigo == 'PRINTER_OFFLINE'
            ? 'A impressora não respondeu. Veja se está ligada e com papel.'
            : e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testando = false;
        _recado = 'Não deu para testar agora. Tente de novo.';
      });
    }
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sombraCard(opacidade: .09, blur: 20, y: 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fundo,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Ico.impressora, size: 24, color: cor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_titulo(),
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.2)),
                    const SizedBox(height: 2),
                    Text(_detalhe(),
                        style: TextStyle(
                            fontSize: 12.5, height: 1.3, color: T.inkSoft)),
                  ],
                ),
              ),
              if (_carregando)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: T.tabOff),
                ),
            ],
          ),
          if (_recado.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_recado,
                style: TextStyle(fontSize: 12.5, color: T.inkMedio)),
          ],
          const SizedBox(height: 14),
          AfundaAoTocar(
            onTap: _testando ? () {} : _testar,
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
                        Icon(Ico.impressora, size: 16, color: T.inkMedio),
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
  }

  String _titulo() {
    if (_carregando) return 'Conferindo...';
    if (_semRecurso) return 'Impressora';
    if (!_ligada) return 'Impressora sem resposta';
    return _nome.isEmpty ? 'Impressora funcionando' : _nome;
  }

  String _detalhe() {
    if (_semRecurso) {
      return 'Não dá para conferir daqui. Use o teste para ver se sai papel.';
    }
    if (!_ligada) {
      return _ultimoErro.isNotEmpty
          ? _ultimoErro
          : 'Veja se ela está ligada, com papel e na mesma rede.';
    }
    return _automatica
        ? 'Impressão automática ligada'
        : 'Impressão automática desligada';
  }
}
