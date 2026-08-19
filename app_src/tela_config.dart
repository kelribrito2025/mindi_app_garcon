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
    if (abaSelecionada.value == 1 && mounted) _carregar();
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

  String get _formasAceitas {
    final l = <String>[];
    if (Sessao.aceitaDinheiro) l.add('Dinheiro');
    if (Sessao.aceitaCartao) l.add('Cartão');
    if (Sessao.aceitaPix) l.add('PIX');
    return l.isEmpty ? '—' : l.join(' · ');
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

                    const _Rotulo('ESTABELECIMENTO'),
                    _Cartao(linhas: [
                      _Linha(
                          icone: Ico.selo,
                          cor: T.azul,
                          fundo: T.azulSuave,
                          titulo: 'Nome',
                          valor: Sessao.empresa.isEmpty
                              ? '—'
                              : Sessao.empresa),
                      _Linha(
                          icone: Ico.conta,
                          cor: T.green,
                          fundo: T.greenSuave,
                          titulo: 'Formas de pagamento',
                          valor: _formasAceitas),
                    ]),

                    const _Rotulo('APARÊNCIA'),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: T.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: T.borda),
                        boxShadow: sombraCard(),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: T.amareloSuave,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                                modoEscuro.value ? Ico.lua : Ico.sol,
                                size: 18,
                                color: T.amarelo),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tema escuro',
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: T.ink)),
                                Text(
                                    modoEscuro.value
                                        ? 'Ligado'
                                        : 'Desligado',
                                    style: TextStyle(
                                        fontSize: 12.5, color: T.inkSoft)),
                              ],
                            ),
                          ),
                          ToggleMindi(
                            ligado: modoEscuro.value,
                            aoMudar: (v) async {
                              await salvarTema(v);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      'A taxa de serviço e as formas de pagamento são '
                      'definidas pelo dono no painel.',
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

class _Linha {
  final IconData icone;
  final Color cor, fundo;
  final String titulo, valor;
  const _Linha({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.titulo,
    required this.valor,
  });
}

class _Cartao extends StatelessWidget {
  final List<_Linha> linhas;
  const _Cartao({required this.linhas});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.borda),
        boxShadow: sombraCard(),
      ),
      child: Column(
        children: [
          for (var i = 0; i < linhas.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 64),
                child: Divider(color: T.line, height: 1),
              ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: linhas[i].fundo,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(linhas[i].icone,
                        size: 18, color: linhas[i].cor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(linhas[i].titulo,
                            style: TextStyle(
                                fontSize: 12.5, color: T.inkSoft)),
                        Text(linhas[i].valor,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: T.ink)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
