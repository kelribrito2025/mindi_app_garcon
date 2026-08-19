import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';
import 'cardapio.dart';

/* ================================================================== *
 *  1. ESCOLHER COMPLEMENTOS DE UM PRODUTO
 *  Devolve o mapa opção -> quantidade, ou null se cancelou.
 * ================================================================== */
Future<Map<OpcaoComplemento, int>?> mostrarComplementos(
  BuildContext context, {
  required Produto produto,
  required List<GrupoComplemento> grupos,
}) {
  return showModalBottomSheet<Map<OpcaoComplemento, int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetComplementos(produto: produto, grupos: grupos),
  );
}

class _SheetComplementos extends StatefulWidget {
  final Produto produto;
  final List<GrupoComplemento> grupos;
  const _SheetComplementos({required this.produto, required this.grupos});

  @override
  State<_SheetComplementos> createState() => _SheetComplementosState();
}

class _SheetComplementosState extends State<_SheetComplementos> {
  final Map<OpcaoComplemento, int> _escolhas = {};

  int _totalDoGrupo(GrupoComplemento g) {
    var soma = 0;
    for (final op in g.opcoes) {
      soma += _escolhas[op] ?? 0;
    }
    return soma;
  }

  bool get _podeConfirmar => widget.grupos
      .where((g) => g.obrigatorio)
      .every((g) => _totalDoGrupo(g) >= g.minimo);

  double get _extra {
    var soma = 0.0;
    _escolhas.forEach((op, q) => soma += op.precoValendo * q);
    return soma;
  }

  void _mudar(GrupoComplemento g, OpcaoComplemento op, int passo) {
    final atual = _escolhas[op] ?? 0;
    final novo = atual + passo;
    if (novo < 0) return;
    if (passo > 0 && g.maximo > 0 && _totalDoGrupo(g) >= g.maximo) {
      // grupo de escolha única: troca em vez de bloquear
      if (g.maximo == 1) {
        setState(() {
          for (final o in g.opcoes) {
            _escolhas.remove(o);
          }
          _escolhas[op] = 1;
        });
      }
      return;
    }
    setState(() {
      if (novo == 0) {
        _escolhas.remove(op);
      } else {
        _escolhas[op] = novo;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: altura * .85),
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 16 + MediaQuery.of(context).padding.bottom),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.produto.nome,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text(reais(widget.produto.precoValendo),
                        style: TextStyle(
                            fontSize: 13, height: 1.25, color: T.inkSoft)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.grupos.map(_grupo).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AfundaAoTocar(
            onTap: _podeConfirmar
                ? () => Navigator.of(context).pop(_escolhas)
                : () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _podeConfirmar ? kGradRed : null,
                color: _podeConfirmar ? null : T.campo2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                  _podeConfirmar
                      ? 'Adicionar · ${reais(widget.produto.precoValendo + _extra)}'
                      : 'Escolha as opções obrigatórias',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _podeConfirmar ? Colors.white : T.fraco)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupo(GrupoComplemento g) {
    final faltando = g.obrigatorio && _totalDoGrupo(g) < g.minimo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(g.nome,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ),
              if (g.obrigatorio)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: faltando ? T.redSuave : T.greenSuave,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(faltando ? 'obrigatório' : 'ok',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                          color: faltando ? T.redDark : T.greenEscuro)),
                ),
            ],
          ),
        ),
        ...g.opcoes.where((o) => o.disponivel).map((op) {
          final q = _escolhas[op] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(op.nome,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: T.ink)),
                      if (op.precoValendo > 0)
                        Text('+ ${reais(op.precoValendo)}',
                            style:
                                TextStyle(fontSize: 12, color: T.inkSoft)),
                    ],
                  ),
                ),
                if (g.maximo == 1)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _mudar(g, op, q > 0 ? -1 : 1),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: q > 0 ? T.redDark : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: q > 0 ? T.redDark : T.borda, width: 1.6),
                      ),
                      child: q > 0
                          ? const Icon(Ico.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  )
                else ...[
                  _passo(Ico.menosItem, () => _mudar(g, op, -1)),
                  SizedBox(
                    width: 30,
                    child: Text('$q',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: q > 0 ? T.ink : T.fraco)),
                  ),
                  _passo(Ico.maisItem, () => _mudar(g, op, 1)),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _passo(IconData icone, VoidCallback onTap) => AfundaAoTocar(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.campo,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: T.borda),
          ),
          child: Icon(icone, size: 14, color: T.inkMedio),
        ),
      );
}

/* ================================================================== *
 *  2. IDENTIFICAÇÃO DO CLIENTE NA MESA
 * ================================================================== */
Future<String?> mostrarIdentificacao(BuildContext context,
    {required String atual}) {
  final campo = TextEditingController(text: atual);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
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
            Text('Identificação da mesa',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                    height: 1.15,
                    letterSpacing: -.4)),
            Text('Aparece no card da mesa, para achar rápido',
                style:
                    TextStyle(fontSize: 13, height: 1.25, color: T.inkSoft)),
            const SizedBox(height: 16),
            TextField(
              controller: campo,
              autofocus: true,
              // o servidor corta em 15, então o app já limita aqui
              maxLength: 15,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 15.5, color: T.ink),
              decoration: InputDecoration(
                hintText: 'João, Aniversário, Reunião...',
                hintStyle: TextStyle(color: T.fraco),
                counterText: '',
                filled: true,
                fillColor: T.campo,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: T.borda),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: T.borda),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: T.redDark, width: 1.5),
                ),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 16),
            AfundaAoTocar(
              onTap: () => Navigator.of(ctx).pop(campo.text.trim()),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: kGradRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Salvar',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/* ================================================================== *
 *  3. ENVIAR PEDIDO — só enviar ou enviar e imprimir
 *  Devolve 'enviar', 'imprimir' ou null.
 * ================================================================== */
Future<String?> mostrarEnviarPedido(BuildContext context,
    {required int itens}) {
  return showModalBottomSheet<String>(
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
                  color: T.redSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Ico.cozinha, size: 23, color: T.redDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enviar pedido',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text('$itens ${itens == 1 ? "item" : "itens"} para a cozinha',
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
          const SizedBox(height: 20),
          AfundaAoTocar(
            onTap: () => Navigator.of(ctx).pop('imprimir'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: kGradRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Ico.impressora, size: 18, color: Colors.white),
                  SizedBox(width: 9),
                  Text('Enviar e imprimir',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AfundaAoTocar(
            onTap: () => Navigator.of(ctx).pop('enviar'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.campo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.borda),
              ),
              child: Text('Apenas enviar',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: T.inkMedio)),
            ),
          ),
          const SizedBox(height: 12),
          Text('"Apenas enviar" manda para a mesa sem passar pela impressora.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: T.inkSoft)),
        ],
      ),
    ),
  );
}

/* ================================================================== *
 *  4. HISTÓRICO DA MESA
 * ================================================================== */
Future<void> mostrarHistoricoDaMesa(BuildContext context,
    {required Mesa mesa}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetHistorico(mesa: mesa),
  );
}

class _SheetHistorico extends StatefulWidget {
  final Mesa mesa;
  const _SheetHistorico({required this.mesa});

  @override
  State<_SheetHistorico> createState() => _SheetHistoricoState();
}

class _SheetHistoricoState extends State<_SheetHistorico> {
  List<ComandaFechada> _comandas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final r = await Api.historicoDaMesa(widget.mesa.id);
      if (!mounted) return;
      setState(() => _comandas = r.map(ComandaFechada.fromJson).toList());
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível ver o histórico.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: altura * .85),
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 18 + MediaQuery.of(context).padding.bottom),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico da mesa',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text(
                        'Mesa ${widget.mesa.titulo} · últimos 30 dias',
                        style: TextStyle(
                            fontSize: 13, height: 1.25, color: T.inkSoft)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
          const SizedBox(height: 16),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Espera(texto: 'Buscando...'),
            )
          else if (_erro != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Text(_erro!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: T.redDark)),
            )
          else if (_comandas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  Icon(Ico.historico, size: 30, color: T.fraco),
                  const SizedBox(height: 10),
                  Text('Nenhuma conta fechada aqui',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: T.ink)),
                  const SizedBox(height: 4),
                  Text('Esta mesa ainda não teve comanda fechada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: _comandas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) => _cartao(_comandas[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartao(ComandaFechada c) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: T.campo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.quando,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: T.ink)),
                    Text(
                        [
                          if (c.numero.isNotEmpty) c.numero,
                          '${c.totalDeItens} '
                              '${c.totalDeItens == 1 ? "item" : "itens"}',
                          if (c.pagamento.isNotEmpty)
                            formaPagamento(c.pagamento),
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: T.inkSoft)),
                  ],
                ),
              ),
              Text(reais(c.total),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -.3)),
            ],
          ),
          if (c.itens.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: T.line, height: 1),
            const SizedBox(height: 8),
            ...c.itens.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text('${it.quantidade}x',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: T.inkSoft)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.nome,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: T.ink)),
                            if (it.complementos.isNotEmpty)
                              Text(it.complementos.join(', '),
                                  style: TextStyle(
                                      fontSize: 11.5, color: T.inkSoft)),
                            if (it.observacao.isNotEmpty)
                              Text(it.observacao,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      color: T.inkSoft)),
                          ],
                        ),
                      ),
                      Text(reais(it.precoTotal),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: T.inkMedio)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
