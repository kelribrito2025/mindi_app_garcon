import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';
import 'sheet_detalhe_ganho.dart';

/* ================================================================== *
 *  HISTÓRICO DE GANHOS — todas as mesas que o garçom fechou
 *  Período livre (escolhe as duas datas), agrupado por dia.
 * ================================================================== */
class TelaHistoricoGanhos extends StatefulWidget {
  const TelaHistoricoGanhos({super.key});

  @override
  State<TelaHistoricoGanhos> createState() => _TelaHistoricoGanhosState();
}

class _TelaHistoricoGanhosState extends State<TelaHistoricoGanhos> {
  late DateTime _de;
  late DateTime _ate;

  List<ComandaDoGarcom> _mesas = [];
  Map<String, dynamic> _resumo = {};
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _ate = hoje;
    _de = hoje.subtract(const Duration(days: 15));
    _buscar();
  }

  Future<void> _buscar() async {
    if (!apiConfigurada) {
      setState(() => _carregando = false);
      return;
    }
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await Future.wait([
        Api.minhasComandas(de: _de, ate: _ate),
        Api.ganhos(de: _de, ate: _ate),
      ]);
      if (!mounted) return;
      setState(() {
        _mesas = (r[0] as List<Map<String, dynamic>>)
            .map(ComandaDoGarcom.fromJson)
            .toList();
        _resumo = r[1] as Map<String, dynamic>;
        _carregando = false;
      });
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar o histórico.';
        _carregando = false;
      });
    }
  }

  /* ---------------- datas ---------------- */
  String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  String _dma(DateTime d) => '${_dm(d)}/${d.year}';

  Future<void> _escolherData(bool inicio) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _de : _ate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: T.redDark),
        ),
        child: child!,
      ),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _de = escolhida;
        if (_ate.isBefore(_de)) _ate = _de;
      } else {
        _ate = escolhida;
        if (_de.isAfter(_ate)) _de = _ate;
      }
    });
    _buscar();
  }

  /// Hoje / Ontem / data
  String _rotuloDia(DateTime d) {
    final hoje = DateTime.now();
    final dia = DateTime(d.year, d.month, d.day);
    final ref = DateTime(hoje.year, hoje.month, hoje.day);
    final diff = ref.difference(dia).inDays;
    if (diff == 0) return 'Hoje — ${_dm(d)}';
    if (diff == 1) return 'Ontem — ${_dm(d)}';
    return _dm(d);
  }

  String _valor(dynamic v) {
    if (v == null) return '—';
    final n =
        v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '.'));
    return n == null ? '—' : reaisCurto(n);
  }

  @override
  Widget build(BuildContext context) {
    // agrupa por dia mantendo a ordem que veio da API
    final grupos = <String, List<ComandaDoGarcom>>{};
    for (final c in _mesas) {
      final d = c.fechadaEm;
      final chave = d == null ? 'Sem data' : _rotuloDia(d);
      grupos.putIfAbsent(chave, () => []).add(c);
    }

    return TelaInterna(
      titulo: 'Histórico de ganhos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- período ----------
          Row(
            children: [
              Expanded(
                  child: _CampoData(
                      texto: _dma(_de), onTap: () => _escolherData(true))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Ico.seta, size: 18, color: T.inkSoft),
              ),
              Expanded(
                  child: _CampoData(
                      texto: _dma(_ate), onTap: () => _escolherData(false))),
            ],
          ),
          const SizedBox(height: 14),

          // ---------- totais do período ----------
          Row(
            children: [
              _Caixa(
                  valor: '${_resumo['totalTables'] ?? _mesas.length}',
                  label: 'mesas'),
              const SizedBox(width: 10),
              _Caixa(
                  valor: _valor(_resumo['totalEarnings']),
                  label: 'comissão',
                  cor: T.green),
              const SizedBox(width: 10),
              _Caixa(
                  valor: _valor(_resumo['totalSales']), label: 'vendido'),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- lista ----------
          if (_carregando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child:
                  Center(child: CircularProgressIndicator(color: T.redDark)),
            )
          else if (_erro != null)
            _Vazio(texto: _erro!, onTentar: _buscar)
          else if (_mesas.isEmpty)
            const _Vazio(texto: 'Nenhuma mesa fechada nesse período')
          else
            Container(
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: sombraCard(),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final grupo in grupos.entries) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      color: T.campo,
                      child: Text(grupo.key,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: T.inkSoft)),
                    ),
                    for (final c in grupo.value)
                      _Linha(
                          comanda: c,
                          aoTocar: () =>
                              mostrarDetalheDaMesa(context, c)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ---------------- campo de data ---------------- */
class _CampoData extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;
  const _CampoData({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.borda),
        ),
        child: Row(
          children: [
            Icon(Ico.calendario, size: 15, color: T.inkSoft),
            const SizedBox(width: 9),
            Text(texto,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: T.ink)),
          ],
        ),
      ),
    );
  }
}

/* ---------------- caixinha de total ---------------- */
class _Caixa extends StatelessWidget {
  final String valor, label;
  final Color? cor;
  const _Caixa({required this.valor, required this.label, this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.borda),
        ),
        child: Column(
          children: [
            Text(valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                    color: cor ?? T.ink)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 11, color: T.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/* ---------------- lista vazia / erro ---------------- */
class _Vazio extends StatelessWidget {
  final String texto;
  final VoidCallback? onTentar;
  const _Vazio({required this.texto, this.onTentar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: sombraCard(),
      ),
      child: Column(
        children: [
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: T.inkSoft)),
          if (onTentar != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTentar,
              child: Text('Tentar de novo',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: T.redDark)),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------- uma mesa do histórico ---------------- */
class _Linha extends StatelessWidget {
  final ComandaDoGarcom comanda;
  final VoidCallback? aoTocar;
  const _Linha({required this.comanda, this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.redSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Ico.mesa, size: 17, color: T.redDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      [
                        c.titulo,
                        if (c.identificacao.isNotEmpty) c.identificacao,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                          letterSpacing: -.2)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        if (c.hora.isNotEmpty) c.hora,
                        reaisCurto(c.total),
                        if (c.formasUsadas.isNotEmpty) c.formasUsadas,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: T.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(reaisCurto(c.comissao),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: T.green)),
            const SizedBox(width: 2),
            Icon(Ico.avancar, size: 19, color: T.fraco),
          ],
        ),
      ),
    );
  }
}
