import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'sessao.dart';
import 'modelos.dart';

/* ================================================================== *
 *  1. FECHAR PARCIAL — o cliente paga SÓ OS ITENS DELE
 *
 *  Os itens escolhidos saem da comanda (viram "cancelados" no
 *  servidor, para não sumir do histórico) e a mesa continua aberta
 *  com o resto. Se não sobrar nenhum item, o servidor fecha a mesa.
 *
 *  Devolve true quando registrou.
 * ================================================================== */
Future<bool?> mostrarFecharParcial(
  BuildContext context, {
  required int mesaId,
  required String mesa,
  required List<ItemComanda> itens,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) =>
        _SheetParcial(mesaId: mesaId, mesa: mesa, itens: itens),
  );
}

class _SheetParcial extends StatefulWidget {
  final int mesaId;
  final String mesa;
  final List<ItemComanda> itens;
  const _SheetParcial({
    required this.mesaId,
    required this.mesa,
    required this.itens,
  });

  @override
  State<_SheetParcial> createState() => _SheetParcialState();
}

class _SheetParcialState extends State<_SheetParcial> {
  final Set<int> _escolhidos = {};
  String _forma = '';
  bool _ocupado = false;
  String? _erro;

  double get _subtotal => widget.itens
      .where((i) => _escolhidos.contains(i.id))
      .fold(0.0, (soma, i) => soma + i.precoTotal);

  double get _taxa => _subtotal * (Sessao.taxaServico / 100);
  double get _total => _subtotal + _taxa;

  bool get _podeEnviar =>
      _escolhidos.isNotEmpty && _forma.isNotEmpty && !_ocupado;

  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await Api.fecharParcial(widget.mesaId,
          itens: _escolhidos.toList(), formaPagamento: _forma);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = _recado(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = 'Não deu para registrar agora. Tente de novo.';
      });
    }
  }

  String _recado(ApiErro e) {
    switch (e.codigo) {
      case 'TAB_ALREADY_CLOSED':
        return 'Essa mesa já foi fechada.';
      case 'NO_VALID_ITEMS':
        return 'Esses itens não estão mais na comanda.';
      default:
        return e.mensagem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: altura * .88),
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
          CabecalhoDePagamento(
            mesa: widget.mesa,
            titulo: 'Fechar parcial',
            subtitulo: 'Marque os itens que estão sendo pagos',
          ),
          const SizedBox(height: 14),
          Flexible(
            child: widget.itens.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text('Nenhum item para pagar',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: T.inkSoft)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.itens.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: T.line, height: 1),
                    itemBuilder: (_, i) => _linhaItem(widget.itens[i]),
                  ),
          ),
          const SizedBox(height: 12),
          if (_escolhidos.isNotEmpty) ...[
            _resumo(),
            const SizedBox(height: 12),
          ],
          EscolhaDeForma(
            forma: _forma,
            aoEscolher: (f) => setState(() => _forma = f),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(_erro!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: T.redDark)),
          ],
          const SizedBox(height: 14),
          BotaoDePagamento(
            texto: _escolhidos.isEmpty
                ? 'Marque os itens'
                : 'Receber ${reais(_total)}',
            ativo: _podeEnviar,
            carregando: _ocupado,
            onTap: _enviar,
          ),
        ],
      ),
    );
  }

  Widget _linhaItem(ItemComanda i) {
    final marcado = _escolhidos.contains(i.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (marcado) {
          _escolhidos.remove(i.id);
        } else {
          _escolhidos.add(i.id);
        }
      }),
      child: Container(
        color: marcado ? T.redSuave.withOpacity(.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marcado ? T.redDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: marcado ? T.redDark : T.borda, width: 1.8),
              ),
              child: marcado
                  ? const Icon(Ico.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i.quantidade}x ${i.nome}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: T.ink)),
                  if (i.complementos.isNotEmpty)
                    Text(i.complementos.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: T.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(reais(i.precoTotal),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: T.ink)),
          ],
        ),
      ),
    );
  }

  Widget _resumo() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: T.campo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.borda),
      ),
      child: Column(
        children: [
          _linhaValor('${_escolhidos.length} '
              '${_escolhidos.length == 1 ? "item" : "itens"}', _subtotal),
          if (Sessao.taxaServico > 0)
            _linhaValor(
                'Taxa de serviço '
                '(${Sessao.taxaServico.toStringAsFixed(0)}%)',
                _taxa),
          const SizedBox(height: 5),
          Divider(color: T.line, height: 1),
          const SizedBox(height: 7),
          _linhaValor('Total', _total, forte: true),
        ],
      ),
    );
  }

  Widget _linhaValor(String rotulo, double valor, {bool forte = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(rotulo,
                style: TextStyle(
                    fontSize: forte ? 14.5 : 13,
                    fontWeight: forte ? FontWeight.w800 : FontWeight.w500,
                    color: forte ? T.ink : T.inkSoft)),
            Text(reais(valor),
                style: TextStyle(
                    fontSize: forte ? 16 : 13,
                    fontWeight: FontWeight.w800,
                    color: forte ? T.ink : T.inkMedio)),
          ],
        ),
      );
}

/* ================================================================== *
 *  2. PAGAMENTO AVULSO — abate um valor do saldo
 * ================================================================== */
Future<bool?> mostrarPagamentoAvulso(
  BuildContext context, {
  required int mesaId,
  required String mesa,
  required double saldo,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetAvulso(mesaId: mesaId, mesa: mesa, saldo: saldo),
  );
}

class _SheetAvulso extends StatefulWidget {
  final int mesaId;
  final String mesa;
  final double saldo;
  const _SheetAvulso({
    required this.mesaId,
    required this.mesa,
    required this.saldo,
  });

  @override
  State<_SheetAvulso> createState() => _SheetAvulsoState();
}

class _SheetAvulsoState extends State<_SheetAvulso> {
  final _valor = TextEditingController();
  final _obs = TextEditingController();
  String _forma = '';
  bool _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _obs.dispose();
    super.dispose();
  }

  double get _quanto {
    final t = _valor.text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  bool get _passaDoSaldo => _quanto > widget.saldo + 0.009;

  bool get _podeEnviar =>
      _quanto > 0 && !_passaDoSaldo && _forma.isNotEmpty && !_ocupado;

  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await Api.pagamentoAvulso(widget.mesaId,
          valor: _quanto,
          formaPagamento: _forma,
          observacao: _obs.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = e.codigo == 'AMOUNT_EXCEEDS_BALANCE'
            ? 'Esse valor é maior do que o saldo da mesa.'
            : e.codigo == 'TAB_ALREADY_CLOSED'
                ? 'Essa mesa já foi fechada.'
                : e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = 'Não deu para registrar agora. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
            CabecalhoDePagamento(
              mesa: widget.mesa,
              titulo: 'Pagamento avulso',
              subtitulo: 'Saldo em aberto: ${reais(widget.saldo)}',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _valor,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
              ],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: T.ink),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: T.inkSoft),
                hintText: '0,00',
                hintStyle: TextStyle(color: T.fraco),
                filled: true,
                fillColor: T.campo,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            ),
            if (_passaDoSaldo)
              Padding(
                padding: const EdgeInsets.only(top: 7, left: 4),
                child: Text(
                    'O saldo da mesa é ${reais(widget.saldo)}',
                    style: TextStyle(fontSize: 12.5, color: T.redDark)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _obs,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14.5, color: T.ink),
              decoration: InputDecoration(
                hintText: 'De quem é esse pagamento? (opcional)',
                hintStyle: TextStyle(color: T.fraco, fontSize: 13.5),
                counterText: '',
                filled: true,
                fillColor: T.campo,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            ),
            const SizedBox(height: 12),
            EscolhaDeForma(
              forma: _forma,
              aoEscolher: (f) => setState(() => _forma = f),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: T.redDark)),
            ],
            const SizedBox(height: 8),
            Text('Pagamento registrado não pode ser desfeito no app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: T.inkSoft)),
            const SizedBox(height: 12),
            BotaoDePagamento(
              texto: _quanto > 0 ? 'Receber ${reais(_quanto)}' : 'Receber',
              ativo: _podeEnviar,
              carregando: _ocupado,
              onTap: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

/* ================================================================== *
 *  PEDAÇOS COMPARTILHADOS
 * ================================================================== */
class CabecalhoDePagamento extends StatelessWidget {
  final String mesa, titulo, subtitulo;
  const CabecalhoDePagamento({
    super.key,
    required this.mesa,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 50),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.redSuave,
            borderRadius: BorderRadius.circular(16),
          ),
          child: mesa.isEmpty
              ? Icon(Ico.mesa, size: 23, color: T.redDark)
              : Text(mesa,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: mesa.length > 2 ? 15 : 19,
                      fontWeight: FontWeight.w800,
                      color: T.redDark,
                      letterSpacing: -.4)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$titulo${mesa.isEmpty ? '' : ' $mesa'}',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      height: 1.15,
                      letterSpacing: -.4)),
              Text(subtitulo,
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
    );
  }
}

/// Dinheiro / Cartão / PIX, respeitando o que o estabelecimento aceita
class EscolhaDeForma extends StatelessWidget {
  final String forma;
  final ValueChanged<String> aoEscolher;
  const EscolhaDeForma(
      {super.key, required this.forma, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    final opcoes = <List<dynamic>>[
      if (Sessao.aceitaDinheiro) ['cash', 'Dinheiro', Ico.conta],
      if (Sessao.aceitaCartao) ['card', 'Cartão', Ico.cartao],
      if (Sessao.aceitaPix) ['pix', 'PIX', Ico.pix],
    ];
    // se o servidor não disse nada, mostra as três
    final lista = opcoes.isEmpty
        ? <List<dynamic>>[
            ['cash', 'Dinheiro', Ico.conta],
            ['card', 'Cartão', Ico.cartao],
            ['pix', 'PIX', Ico.pix],
          ]
        : opcoes;

    return Row(
      children: [
        for (var i = 0; i < lista.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: AfundaAoTocar(
              onTap: () => aoEscolher(lista[i][0] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: forma == lista[i][0] ? T.redSuave : T.campo,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: forma == lista[i][0] ? T.redDark : T.borda,
                      width: forma == lista[i][0] ? 1.5 : 1),
                ),
                child: Column(
                  children: [
                    Icon(lista[i][2] as IconData,
                        size: 19,
                        color: forma == lista[i][0] ? T.redDark : T.inkMedio),
                    const SizedBox(height: 5),
                    Text(lista[i][1] as String,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: forma == lista[i][0]
                                ? T.redDark
                                : T.inkMedio)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class BotaoDePagamento extends StatelessWidget {
  final String texto;
  final bool ativo, carregando;
  final VoidCallback onTap;
  const BotaoDePagamento({
    super.key,
    required this.texto,
    required this.ativo,
    required this.carregando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AfundaAoTocar(
        onTap: ativo ? onTap : () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: ativo ? kGradRed : null,
            color: ativo ? null : T.campo2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: carregando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(texto,
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: ativo ? Colors.white : T.fraco)),
        ),
      );
}
