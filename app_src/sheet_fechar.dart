import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tema.dart';
import 'icones.dart';
import 'modelos.dart';
import 'sessao.dart';

/* ================================================================== *
 *  MODAL DE FECHAMENTO DA MESA
 *  Escolhe a forma de pagamento, confere o valor e calcula o troco.
 * ================================================================== */
class Fechamento {
  final String forma;
  final double pago;
  final double troco;
  const Fechamento(
      {required this.forma, required this.pago, this.troco = 0});
}

Future<Fechamento?> mostrarFechamento(BuildContext context,
    {required double total}) {
  return showModalBottomSheet<Fechamento>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetFechar(total: total),
  );
}

class _SheetFechar extends StatefulWidget {
  final double total;
  const _SheetFechar({required this.total});

  @override
  State<_SheetFechar> createState() => _SheetFecharState();
}

class _SheetFecharState extends State<_SheetFechar> {
  String _forma = '';
  final _recebido = TextEditingController();

  @override
  void initState() {
    super.initState();
    _forma = _formasAceitas.isEmpty ? 'cash' : _formasAceitas.first;
  }

  @override
  void dispose() {
    _recebido.dispose();
    super.dispose();
  }

  List<String> get _formasAceitas {
    final l = <String>[];
    if (Sessao.aceitaDinheiro) l.add('cash');
    if (Sessao.aceitaCartao) l.add('card');
    if (Sessao.aceitaPix) l.add('pix');
    // se o servidor não informou nada, mostra as três
    return l.isEmpty ? ['cash', 'card', 'pix'] : l;
  }

  bool get _dinheiro => _forma == 'cash';

  double get _valorRecebido {
    final t = _recebido.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.isEmpty) return 0;
    return (int.tryParse(t) ?? 0) / 100;
  }

  double get _troco {
    if (!_dinheiro) return 0;
    final t = _valorRecebido - widget.total;
    return t > 0 ? t : 0;
  }

  bool get _podeFechar {
    if (!_dinheiro) return true;
    return _valorRecebido >= widget.total;
  }

  IconData _icone(String f) {
    switch (f) {
      case 'cash':
        return Ico.conta;
      case 'pix':
        return Ico.pix;
      default:
        return Ico.cartao;
    }
  }

  @override
  Widget build(BuildContext context) {
    final margem = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: margem),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
                  child: Text('Fechar a mesa',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                          letterSpacing: -.4)),
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

            // ---------- total ----------
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.redSuave,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: T.redBorda),
              ),
              child: Column(
                children: [
                  Text('Total a receber',
                      style: TextStyle(fontSize: 12.5, color: T.redDark)),
                  const SizedBox(height: 3),
                  Text(reais(widget.total),
                      style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: T.redDark,
                          letterSpacing: -.8)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ---------- forma de pagamento ----------
            Text('Forma de pagamento',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: T.rotulo)),
            const SizedBox(height: 9),
            Row(
              children: [
                for (final f in _formasAceitas) ...[
                  Expanded(
                    child: AfundaAoTocar(
                      onTap: () => setState(() => _forma = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _forma == f ? T.redSuave : T.campo,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _forma == f ? T.redDark : T.borda,
                              width: _forma == f ? 1.5 : 1),
                        ),
                        child: Column(
                          children: [
                            Icon(_icone(f),
                                size: 19,
                                color: _forma == f ? T.redDark : T.inkSoft),
                            const SizedBox(height: 5),
                            Text(formaPagamento(f),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        _forma == f ? T.redDark : T.inkMedio)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (f != _formasAceitas.last) const SizedBox(width: 9),
                ],
              ],
            ),

            // ---------- troco ----------
            if (_dinheiro) ...[
              const SizedBox(height: 18),
              Text('Valor recebido',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: T.rotulo)),
              const SizedBox(height: 8),
              TextField(
                controller: _recebido,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: T.ink),
                decoration: InputDecoration(
                  hintText: 'R\$ 0,00',
                  hintStyle: TextStyle(color: T.fraco),
                  prefixText: _recebido.text.isEmpty
                      ? ''
                      : '${reais(_valorRecebido)}  ',
                  prefixStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: T.ink),
                  filled: true,
                  fillColor: T.campo,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 15),
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _troco > 0 ? T.greenSuave : T.campo,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _troco > 0 ? T.greenBorda : T.borda),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Troco',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _troco > 0 ? T.greenEscuro : T.inkSoft)),
                    Text(reais(_troco),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _troco > 0 ? T.greenEscuro : T.inkSoft)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            AfundaAoTocar(
              onTap: !_podeFechar
                  ? () {}
                  : () => Navigator.of(context).pop(Fechamento(
                        forma: _forma,
                        pago: _dinheiro ? _valorRecebido : widget.total,
                        troco: _troco,
                      )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _podeFechar ? kGradRed : null,
                  color: _podeFechar ? null : T.campo2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                    _podeFechar
                        ? 'Confirmar pagamento'
                        : 'Valor menor que o total',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: _podeFechar ? Colors.white : T.fraco)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
