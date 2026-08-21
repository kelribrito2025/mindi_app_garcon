import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tema.dart';
import 'estado.dart';
import 'icones.dart';
import 'api.dart';
import 'sessao.dart';
import 'modelos.dart';
import 'sheet_detalhe_ganho.dart';
import 'tela_historico_ganhos.dart';

/* ================================================================== *
 *  ABA GANHOS — a comissão do garçom
 *
 *  A comissão é a taxa de serviço das mesas que ele atendeu. Quando o
 *  estabelecimento manda a taxa para a casa (e não para a equipe), a
 *  tela explica isso em vez de mostrar número.
 *
 *  Os endpoints /waiter/earnings e /waiter/history ainda não existem
 *  no servidor. Enquanto não existirem, a tela mostra um aviso calmo
 *  no lugar de um erro feio.
 * ================================================================== */

/// altura de uma linha da lista
const double _alturaLinha = 61;

/// quantas mesas a aba mostra (as mais recentes)
const int _maximoDeMesas = 10;

class TelaGanhos extends StatefulWidget {
  const TelaGanhos({super.key});

  @override
  State<TelaGanhos> createState() => _TelaGanhosState();
}

class _TelaGanhosState extends State<TelaGanhos> {
  String _periodo = 'Hoje';

  Map<String, dynamic> _resumo = {};
  List<ComandaDoGarcom> _mesas = [];
  bool _carregando = true;
  bool _semRecurso = false; // servidor ainda não tem o endpoint
  String? _erro;

  @override
  void initState() {
    super.initState();
    _buscar();
    abaSelecionada.addListener(_aoTrocarAba);
  }

  @override
  void dispose() {
    abaSelecionada.removeListener(_aoTrocarAba);
    super.dispose();
  }

  void _aoTrocarAba() {
    if (abaSelecionada.value == 1 && mounted) _buscar();
  }

  /* ---------------- período escolhido ---------------- */
  (DateTime, DateTime) get _intervalo {
    final hoje = DateTime.now();
    switch (_periodo) {
      case 'Semana':
        return (hoje.subtract(Duration(days: hoje.weekday - 1)), hoje);
      case 'Mês':
        return (DateTime(hoje.year, hoje.month, 1), hoje);
      default:
        return (hoje, hoje);
    }
  }

  String get _rotulo {
    switch (_periodo) {
      case 'Semana':
        return 'COMISSÃO DA SEMANA';
      case 'Mês':
        return 'COMISSÃO DO MÊS';
      default:
        return 'COMISSÃO DE HOJE';
    }
  }

  /// a taxa de serviço vai para a equipe ou fica com a casa?
  bool get _taxaVaiParaEquipe {
    final d = '${Sessao.loja['serviceChargeDestination'] ?? ''}'.toLowerCase();
    // quando o servidor não diz nada, mostra assim mesmo — melhor do que
    // esconder a aba e o garçom achar que sumiu
    return d.isEmpty || d == 'staff';
  }

  /* ---------------- API ---------------- */
  Future<void> _buscar() async {
    if (!apiConfigurada) {
      setState(() => _carregando = false);
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
      _semRecurso = false;
    });

    final (de, ate) = _intervalo;
    try {
      final r = await Future.wait([
        Api.ganhos(de: de, ate: ate),
        Api.minhasComandas(de: de, ate: ate),
      ]);
      if (!mounted) return;
      setState(() {
        _resumo = r[0] as Map<String, dynamic>;
        _mesas = (r[1] as List<Map<String, dynamic>>)
            .map(ComandaDoGarcom.fromJson)
            .take(_maximoDeMesas)
            .toList();
        _carregando = false;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        // 404: o servidor ainda não tem esses endpoints
        _semRecurso = e.status == 404 || e.codigo == 'NOT_FOUND';
        _erro = _semRecurso ? null : e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar os ganhos.';
        _carregando = false;
      });
    }
  }

  double _n(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  /* ---------------- tela ---------------- */
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderVermelho(child: BarraBoasVindas()),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSide),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cartaoGanhos(),
                  const SizedBox(height: 18),
                  _tituloSecao(),
                  const SizedBox(height: 9),
                  Expanded(child: _lista()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /* ---------------- cartão de cima ---------------- */
  Widget _cartaoGanhos() {
    final total = _n(_resumo['totalEarnings']);
    final vendido = _n(_resumo['totalSales']);
    final taxa = _n(_resumo['serviceChargeRate']) > 0
        ? _n(_resumo['serviceChargeRate'])
        : Sessao.taxaServico;
    final partes = total.toStringAsFixed(2).split('.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: sombraCard(opacidade: .10, blur: 26, y: 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seletorDePeriodo(),
          const SizedBox(height: 16),
          Text(_rotulo,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: T.inkSoft)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _carregando
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Espera(texto: 'Carregando...', tamanho: 17),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('R\$ ',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: T.inkSoft)),
                          Text('${partes[0]},${partes[1]}',
                              style: TextStyle(
                                  fontSize: 35,
                                  fontWeight: FontWeight.w800,
                                  color: T.ink,
                                  letterSpacing: -1)),
                        ],
                      ),
              ),
            ],
          ),

          // explica de onde saiu o número
          if (!_carregando && taxa > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                  vendido > 0
                      ? '${taxa.toStringAsFixed(taxa % 1 == 0 ? 0 : 1)}% de ${reaisCurto(vendido)} atendidos'
                      : 'taxa de serviço de ${taxa.toStringAsFixed(taxa % 1 == 0 ? 0 : 1)}%',
                  style: TextStyle(fontSize: 12, color: T.inkSoft)),
            ),

          const SizedBox(height: 16),
          Divider(color: T.line, height: 1),
          const SizedBox(height: 13),
          Row(
            children: [
              _Num(
                  valor: _carregando
                      ? '—'
                      : '${_resumo['totalTables'] ?? _mesas.length}',
                  label: 'mesas'),
              _Num(
                  valor: _carregando
                      ? '—'
                      : reaisCurto(_n(_resumo['averagePerTable'])),
                  label: 'média',
                  divisor: true),
              _Num(
                  valor: _carregando ? '—' : reaisCurto(vendido),
                  label: 'vendido',
                  divisor: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seletorDePeriodo() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: T.campo2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: ['Hoje', 'Semana', 'Mês'].map((p) {
          final on = p == _periodo;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _periodo = p);
                _buscar();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? T.card : null,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(.10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(p,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: on ? T.ink : T.inkSoft,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tituloSecao() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              _periodo == 'Hoje' ? 'MESAS DE HOJE' : 'MESAS DO PERÍODO',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: T.inkSoft)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TelaHistoricoGanhos())),
            child: Text('Ver todas',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: T.redDark)),
          ),
        ],
      ),
    );
  }

  /* ---------------- lista ---------------- */
  Widget _lista() {
    final alturaMax = _alturaLinha * _mesas.length + 12;

    return LayoutBuilder(
      builder: (context, cons) {
        final disponivel =
            cons.maxHeight - 70 - MediaQuery.of(context).padding.bottom;
        final altura = _carregando || _mesas.isEmpty
            ? math.max(math.min(160.0, disponivel), 0.0)
            : math.min(alturaMax, math.max(disponivel, 0.0));

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: altura,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(22),
                boxShadow: sombraCard(),
              ),
              child: _conteudoDaLista(),
            ),
          ),
        );
      },
    );
  }

  Widget _conteudoDaLista() {
    if (_carregando) {
      return const Center(child: Espera(texto: 'Carregando...', tamanho: 14));
    }

    if (_semRecurso) {
      return _aviso('Comissão ainda não disponível',
          'O restaurante precisa ligar o controle de comissão por garçom '
          'no sistema. Assim que ligar, seus ganhos aparecem aqui.');
    }

    if (!_taxaVaiParaEquipe) {
      return _aviso('A taxa fica com a casa',
          'Neste restaurante a taxa de serviço não é repassada para a '
          'equipe, então não há comissão a mostrar.');
    }

    if (_erro != null) {
      return Center(
        child: GestureDetector(
          onTap: _buscar,
          child: Text(_erro!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
        ),
      );
    }

    if (_mesas.isEmpty) {
      return Center(
        child: Text('Nenhuma mesa fechada nesse período',
            style: TextStyle(fontSize: 13, color: T.inkSoft)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: _mesas.length,
      itemBuilder: (context, i) => _LinhaMesaFechada(
        comanda: _mesas[i],
        ultima: i == _mesas.length - 1,
        aoTocar: () => mostrarDetalheDaMesa(context, _mesas[i]),
      ),
    );
  }

  Widget _aviso(String titulo, String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Ico.ganhos, size: 30, color: T.fraco),
              const SizedBox(height: 10),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.ink)),
              const SizedBox(height: 4),
              Text(texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.3, color: T.inkSoft)),
            ],
          ),
        ),
      );
}

/* ---------------- uma linha da lista ---------------- */
class _LinhaMesaFechada extends StatelessWidget {
  final ComandaDoGarcom comanda;
  final bool ultima;
  final VoidCallback aoTocar;
  const _LinhaMesaFechada(
      {required this.comanda, required this.ultima, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
      height: _alturaLinha,
      decoration: BoxDecoration(
        border: ultima ? null : Border(bottom: BorderSide(color: T.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.redSuave,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Ico.mesa, size: 18, color: T.redDark),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                            letterSpacing: -.2)),
                    if (c.formasUsadas.isNotEmpty) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(c.formasUsadas,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: T.inkMedio)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    [
                      if (c.identificacao.isNotEmpty) c.identificacao,
                      reaisCurto(c.total),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: T.inkSoft)),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(reaisCurto(c.comissao),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.green)),
              const SizedBox(height: 2),
              Text(c.hora,
                  style: TextStyle(fontSize: 11, color: T.inkSoft)),
            ],
          ),
          const SizedBox(width: 2),
          Icon(Ico.avancar, size: 19, color: T.fraco),
        ],
      ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  final String valor, label;
  final bool divisor;
  final Color? cor;
  const _Num(
      {required this.valor,
      required this.label,
      this.divisor = false,
      this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (divisor)
            Positioned(
              left: 0,
              top: 3,
              bottom: 3,
              child: Container(width: 1, color: T.line),
            ),
          Column(
            children: [
              Text(valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cor ?? T.ink,
                      letterSpacing: -.3)),
              Text(label,
                  style: TextStyle(fontSize: 11, color: T.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
