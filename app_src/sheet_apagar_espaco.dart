import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';

/* ================================================================== *
 *  MODAL "APAGAR ESPAÇO"
 *  Aparece ao segurar o dedo no nome de um espaço.
 *  Devolve TRUE quando o espaço foi apagado.
 * ================================================================== */
Future<bool?> mostrarApagarEspaco(
  BuildContext context, {
  required int espacoId,
  required String nome,
  required int mesas,
  required int ocupadas,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetApagar(
      espacoId: espacoId,
      nome: nome,
      mesas: mesas,
      ocupadas: ocupadas,
    ),
  );
}

class _SheetApagar extends StatefulWidget {
  final int espacoId;
  final String nome;
  final int mesas;
  final int ocupadas;
  const _SheetApagar({
    required this.espacoId,
    required this.nome,
    required this.mesas,
    required this.ocupadas,
  });

  @override
  State<_SheetApagar> createState() => _SheetApagarState();
}

class _SheetApagarState extends State<_SheetApagar> {
  bool _apagando = false;
  String? _erro;

  /// espaço com mesa aberta não pode ser apagado: existe comanda viva ali
  bool get _bloqueado => widget.ocupadas > 0;

  Future<void> _apagar() async {
    setState(() {
      _apagando = true;
      _erro = null;
    });
    try {
      await Api.apagarEspaco(widget.espacoId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      // outro garçom apagou primeiro: o resultado é o mesmo que a gente
      // queria, então fecha como sucesso em vez de assustar com erro
      if (e.codigo == 'SPACE_NOT_FOUND') {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível apagar o espaço.');
    } finally {
      if (mounted) setState(() => _apagando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final margem = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 20, 18, 18 + margem),
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
                  color: _bloqueado ? T.amareloSuave : T.redSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_bloqueado ? Ico.relogio : Ico.lixeira,
                    size: 23, color: _bloqueado ? T.amarelo : T.redDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_bloqueado ? 'Não dá para apagar' : 'Apagar espaço',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            letterSpacing: -.4)),
                    const SizedBox(height: 2),
                    Text(widget.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: T.inkSoft)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
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

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bloqueado ? T.amareloSuave : T.campo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _bloqueado ? T.amareloBorda : T.borda),
            ),
            child: Text(
              _bloqueado
                  ? 'Este espaço tem ${widget.ocupadas} '
                      '${widget.ocupadas == 1 ? "mesa aberta" : "mesas abertas"}. '
                      'Feche ${widget.ocupadas == 1 ? "ela" : "todas"} antes de apagar, '
                      'senão as comandas se perdem.'
                  : 'As ${widget.mesas} '
                      '${widget.mesas == 1 ? "mesa" : "mesas"} deste espaço também '
                      'serão apagadas. Isso não pode ser desfeito.',
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: _bloqueado ? T.ink : T.inkMedio),
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                style: TextStyle(fontSize: 12.5, color: T.redDark)),
          ],

          const SizedBox(height: 18),
          if (_bloqueado)
            AfundaAoTocar(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: kGradRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Entendi',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AfundaAoTocar(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.campo,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: T.borda),
                      ),
                      child: Text('Cancelar',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: T.inkMedio)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AfundaAoTocar(
                    onTap: _apagando ? () {} : _apagar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: kGradRed,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _apagando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Apagar',
                              style: TextStyle(
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
}
