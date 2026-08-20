import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';

/* ================================================================== *
 *  JUNTAR MESAS — confirmação depois de arrastar uma mesa na outra
 *
 *  Quem decide qual mesa vira a principal é o servidor: a regra do
 *  PDV é a de MENOR número. O app só antecipa isso na tela para o
 *  garçom não se assustar.
 *
 *  Devolve true quando juntou.
 * ================================================================== */
Future<bool?> mostrarJuntarMesas(
  BuildContext context, {
  required Mesa arrastada,
  required Mesa alvo,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    isDismissible: true,
    builder: (_) => _SheetJuntar(arrastada: arrastada, alvo: alvo),
  );
}

class _SheetJuntar extends StatefulWidget {
  final Mesa arrastada;
  final Mesa alvo;
  const _SheetJuntar({required this.arrastada, required this.alvo});

  @override
  State<_SheetJuntar> createState() => _SheetJuntarState();
}

class _SheetJuntarState extends State<_SheetJuntar> {
  bool _ocupado = false;
  String? _erro;

  /// menor número segura a comanda (mesma regra do PDV)
  Mesa get _principal =>
      widget.arrastada.numero <= widget.alvo.numero
          ? widget.arrastada
          : widget.alvo;

  Mesa get _secundaria =>
      _principal.id == widget.arrastada.id ? widget.alvo : widget.arrastada;

  String get _nomeDoGrupo => '${_principal.numero}-${_secundaria.numero}';

  int get _pessoas => widget.arrastada.pessoas + widget.alvo.pessoas;

  Future<void> _juntar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await Api.juntarMesas(widget.arrastada.id,
          mesaAlvo: widget.alvo.id);
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
        _erro = 'Não deu para juntar agora. Tente de novo.';
      });
    }
  }

  String _recado(ApiErro e) {
    switch (e.codigo) {
      case 'ALREADY_MERGED':
        return 'Uma dessas mesas já está junta com outra.';
      case 'TABLE_REQUESTING_BILL':
        return 'Não dá para juntar: a conta já foi pedida.';
      case 'TABLE_CLOSED':
        return 'Essa mesa já foi fechada.';
      case 'TABLE_NOT_FOUND':
        return 'Essa mesa não existe mais. Puxe a tela para atualizar.';
      default:
        return e.mensagem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.redSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Ico.juntar, size: 23, color: T.redDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Juntar mesas',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text('As duas viram a Mesa $_nomeDoGrupo',
                        style: TextStyle(
                            fontSize: 13, height: 1.25, color: T.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.campo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.borda),
            ),
            child: Column(
              children: [
                _linha(Ico.comanda,
                    'A comanda fica na mesa ${_principal.numero}'),
                const SizedBox(height: 10),
                _linha(Ico.mesas,
                    'A mesa ${_secundaria.numero} passa a fazer parte dela'),
                if (_pessoas > 0) ...[
                  const SizedBox(height: 10),
                  _linha(Ico.pessoas, '$_pessoas pessoas no total'),
                ],
              ],
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: T.redDark)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AfundaAoTocar(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: T.campo,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: T.borda),
                    ),
                    child: Text('Cancelar',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: T.inkMedio)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AfundaAoTocar(
                  onTap: _ocupado ? () {} : _juntar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _ocupado ? null : kGradRed,
                      color: _ocupado ? T.campo2 : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Juntar mesas',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String texto) => Row(
        children: [
          Icon(icone, size: 16, color: T.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: T.inkMedio)),
          ),
        ],
      );
}
