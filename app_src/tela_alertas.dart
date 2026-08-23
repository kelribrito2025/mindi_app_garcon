import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'tema.dart';
import 'icones.dart';
import 'estado.dart';
import 'sessao.dart';

/* ================================================================== *
 *  ABA ALERTAS — as chamadas de "Chamar garçom" das mesas
 *
 *  Esta tela é a dona da lista: busca no servidor a cada 10 segundos
 *  (e na hora, quando chega o push) e guarda em chamadasAtivas.
 *  A aba Mesas e a bolinha da barra de abas só escutam essa lista.
 *
 *  Ações: "Estou indo" avisa a equipe que alguém assumiu;
 *  "Atendido" encerra e o card some para todos os garçons.
 *  Abrir a mesa que está chamando também encerra (fica na aba Mesas).
 * ================================================================== */
class TelaAlertas extends StatefulWidget {
  const TelaAlertas({super.key});

  @override
  State<TelaAlertas> createState() => _TelaAlertasState();
}

class _TelaAlertasState extends State<TelaAlertas> {
  Timer? _vigia;
  Timer? _relogio;
  bool _buscando = false;

  /// chamadas em que EU toquei "Estou indo" (o botão vira "Avisado ✓")
  final Set<int> _avisadas = {};

  /// ids com ação em andamento (evita toque duplo)
  final Set<int> _mexendo = {};

  @override
  void initState() {
    super.initState();
    _buscar();
    // confere no servidor a cada 10 segundos, mesmo fora da aba —
    // é o que mantém a bolinha da barra e o CHAMANDO das mesas em dia
    _vigia = Timer.periodic(const Duration(seconds: 10), (_) => _buscar());
    // com a aba aberta, o "há X segundos" anda sozinho
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (abaSelecionada.value == 1 && mounted) setState(() {});
    });
    avisoDeChamada.addListener(_aoChegarChamada);
    chamadasAtivas.addListener(_redesenhar);
  }

  @override
  void dispose() {
    _vigia?.cancel();
    _relogio?.cancel();
    avisoDeChamada.removeListener(_aoChegarChamada);
    chamadasAtivas.removeListener(_redesenhar);
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  void _aoChegarChamada() => _buscar();

  Future<void> _buscar() async {
    if (!apiConfigurada || !Sessao.logado || _buscando) return;
    _buscando = true;
    try {
      final lista = await Api.chamadasEmAberto();
      // a mais antiga primeiro: é a mesa esperando há mais tempo
      lista.sort((a, b) =>
          '${a['calledAt'] ?? ''}'.compareTo('${b['calledAt'] ?? ''}'));
      chamadasAtivas.value = lista;
    } catch (_) {
      // sem internet: fica com a última lista conhecida
    } finally {
      _buscando = false;
    }
  }

  void _avisar(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? T.green : T.dark2,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /* ---------------- ações ---------------- */

  Future<void> _estouIndo(int id) async {
    if (_mexendo.contains(id)) return;
    setState(() => _mexendo.add(id));
    try {
      await Api.assumirChamada(id);
      setState(() => _avisadas.add(id));
    } catch (e) {
      _avisar(e is ApiErro ? e.mensagem : 'Não deu certo. Tente de novo.');
    } finally {
      if (mounted) setState(() => _mexendo.remove(id));
    }
  }

  Future<void> _atendido(int id) async {
    if (_mexendo.contains(id)) return;
    setState(() => _mexendo.add(id));
    // some da lista na hora (e o CHAMANDO sai da mesa)
    final antes = chamadasAtivas.value;
    chamadasAtivas.value = [
      for (final c in antes)
        if ((c['id'] as num?)?.toInt() != id) c
    ];
    try {
      await Api.concluirChamada(id);
    } catch (e) {
      // não deu: volta o card e avisa
      chamadasAtivas.value = antes;
      _avisar(e is ApiErro ? e.mensagem : 'Não deu certo. Tente de novo.');
    } finally {
      if (mounted) setState(() => _mexendo.remove(id));
    }
  }

  /* ---------------- textos ---------------- */

  static String _nomeDaMesa(Map<String, dynamic> c) {
    final d = '${c['displayNumber'] ?? ''}';
    if (d.isNotEmpty && d != 'null') return d;
    final n = '${c['tableNumber'] ?? ''}';
    return n.isEmpty || n == 'null' ? 'Mesa' : 'Mesa $n';
  }

  static String _tempoDe(Map<String, dynamic> c) {
    final quando = DateTime.tryParse('${c['calledAt'] ?? ''}');
    if (quando == null) return '';
    final s = DateTime.now().difference(quando.toLocal()).inSeconds;
    if (s < 0) return 'agora';
    if (s < 60) return 'há $s segundo${s == 1 ? '' : 's'}';
    final m = s ~/ 60;
    if (m < 60) return 'há $m minuto${m == 1 ? '' : 's'}';
    final h = m ~/ 60;
    return 'há $h hora${h == 1 ? '' : 's'}';
  }

  /* ---------------- visual ---------------- */

  @override
  Widget build(BuildContext context) {
    final chamadas = chamadasAtivas.value;

    return RefreshIndicator(
      color: T.redDark,
      onRefresh: _buscar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
            bottom: 130 + MediaQuery.of(context).padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HeaderVermelho(
              alturaExtra: 18,
              child: BarraBoasVindas(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSide, 16, kSide, 0),
              child: chamadas.isEmpty
                  ? _semChamadas()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 4, bottom: 8),
                          child: Text(
                            'CHAMADAS · ${chamadas.length}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                                color: T.inkSoft),
                          ),
                        ),
                        for (final c in chamadas) ...[
                          _cardChamada(c),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _semChamadas() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          // o radar pulsando, igual ao "Aguardando pedidos" do
          // app do entregador
          const _RadarChamadas(tamanho: 168, nucleo: 68, icone: 30),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: T.redDark),
              ),
              const SizedBox(width: 10),
              Text('Aguardando chamadas',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.3)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 260,
            child: Text(
              'Quando um cliente tocar em "Chamar garçom" '
              'no cardápio da mesa, o aviso aparece aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: T.inkSoft, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardChamada(Map<String, dynamic> c) {
    final id = (c['id'] as num?)?.toInt() ?? 0;
    final ocupado = _mexendo.contains(id);
    final avisei = _avisadas.contains(id) ||
        '${c['status'] ?? ''}' == 'acknowledged';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.redBorda, width: 1.4),
        boxShadow: sombraCard(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.redSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Ico.sino, size: 17, color: T.redDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_nomeDaMesa(c)} está chamando!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: T.ink)),
                    const SizedBox(height: 1),
                    Text(_tempoDe(c),
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: T.redDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (ocupado || avisei) ? null : () => _estouIndo(id),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: avisei ? null : kGradRed,
                      color: avisei ? T.campo : null,
                      borderRadius: BorderRadius.circular(13),
                      border: avisei
                          ? Border.all(color: T.borda)
                          : null,
                    ),
                    child: ocupado
                        ? SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: avisei
                                    ? T.inkSoft
                                    : Colors.white),
                          )
                        : Text(avisei ? 'Avisado ✓' : 'Estou indo',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: avisei
                                    ? T.inkSoft
                                    : Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ocupado ? null : () => _atendido(id),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: T.greenBorda),
                    ),
                    child: Text('Atendido ✓',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: T.greenEscuro)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------- anéis pulsando (igual ao radar do entregador) ---------- */
class _RadarChamadas extends StatefulWidget {
  final double tamanho;
  final double nucleo;
  final double icone;
  const _RadarChamadas({
    this.tamanho = 190,
    this.nucleo = 74,
    this.icone = 34,
  });

  @override
  State<_RadarChamadas> createState() => _RadarChamadasState();
}

class _RadarChamadasState extends State<_RadarChamadas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _anel(double fase) {
    final escala = 0.45 + 0.55 * fase;
    final opacidade =
        fase < 0.15 ? (fase / 0.15) * 0.55 : 0.55 * (1 - (fase - 0.15) / 0.85);
    return Opacity(
      opacity: opacidade.clamp(0.0, 1.0).toDouble(),
      child: Transform.scale(
        scale: escala,
        child: Container(
          width: widget.tamanho,
          height: widget.tamanho,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: T.redDark.withOpacity(.06),
            border:
                Border.all(color: T.redDark.withOpacity(.35), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.tamanho,
      height: widget.tamanho,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _anel(t),
              _anel((t + 1 / 3) % 1),
              _anel((t + 2 / 3) % 1),
              Container(
                width: widget.nucleo,
                height: widget.nucleo,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC5B57), Color(0xFFD8434B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: T.redDark.withOpacity(.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(Ico.sino,
                    size: widget.icone, color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}
