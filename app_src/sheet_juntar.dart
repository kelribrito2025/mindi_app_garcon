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
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: T.borda,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
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

/* ================================================================== *
 *  SEPARAR MESAS — segurar o dedo no card de um grupo
 *
 *  Duas mesas: só pergunta se quer separar.
 *  Três ou mais: lista as mesas do grupo com uma caixinha marcada.
 *  Desmarcar = essa mesa sai do grupo ao salvar.
 *
 *  Devolve true quando alguma coisa mudou.
 * ================================================================== */
Future<bool?> mostrarSepararMesas(
  BuildContext context, {
  required Mesa principal,
  required List<Mesa> secundarias,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) =>
        _SheetSeparar(principal: principal, secundarias: secundarias),
  );
}

class _SheetSeparar extends StatefulWidget {
  final Mesa principal;
  final List<Mesa> secundarias;
  const _SheetSeparar({required this.principal, required this.secundarias});

  @override
  State<_SheetSeparar> createState() => _SheetSepararState();
}

class _SheetSepararState extends State<_SheetSeparar> {
  /// ids que CONTINUAM juntos (começam todos marcados)
  late final Set<int> _ficam =
      widget.secundarias.map((m) => m.id).toSet();

  bool _ocupado = false;
  String? _erro;

  bool get _umaSo => widget.secundarias.length == 1;

  List<int> get _saem => widget.secundarias
      .map((m) => m.id)
      .where((id) => !_ficam.contains(id))
      .toList();

  Future<void> _salvar() async {
    // com duas mesas o botão separa direto, sem caixinha
    final sair = _umaSo ? [widget.secundarias.first.id] : _saem;
    if (sair.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      // O servidor só aceita desfazer o grupo pela mesa PRINCIPAL:
      // chamar na secundária devolve TABLE_NOT_MERGED.
      await Api.separarMesa(widget.principal.id);

      // Saiu só uma parte? Junta de volta quem devia continuar.
      final voltam = widget.secundarias
          .map((m) => m.id)
          .where((id) => !sair.contains(id))
          .toList();
      for (final id in voltam) {
        await Api.juntarMesas(id, mesaAlvo: widget.principal.id);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = e.codigo == 'TABLE_NOT_MERGED' || e.codigo == 'NOT_MERGED'
            ? 'Essa mesa já não estava junta.'
            : e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _erro = 'Não deu para separar agora. Tente de novo.';
      });
    }
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
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: T.borda,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
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
                child: Icon(Ico.separar, size: 23, color: T.redDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Separar mesas',
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text('Mesa ${widget.principal.tituloDoGrupo}',
                        style: TextStyle(
                            fontSize: 13, height: 1.25, color: T.inkSoft)),
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
          if (_umaSo) _perguntaSimples() else _listaComCaixinhas(),
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
                  onTap: _ocupado ? () {} : _salvar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: _ocupado || (!_umaSo && _saem.isEmpty)
                          ? null
                          : kGradRed,
                      color: _ocupado || (!_umaSo && _saem.isEmpty)
                          ? T.campo2
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _ocupado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_textoDoBotao(),
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: !_umaSo && _saem.isEmpty
                                    ? T.fraco
                                    : Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _textoDoBotao() {
    if (_umaSo) return 'Separar mesas';
    if (_saem.isEmpty) return 'Desmarque para separar';
    return _saem.length == 1
        ? 'Separar 1 mesa'
        : 'Separar ${_saem.length} mesas';
  }

  Widget _perguntaSimples() {
    final outra = widget.secundarias.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.campo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.borda),
      ),
      child: Column(
        children: [
          Text(
              'A mesa ${outra.titulo} volta a ficar livre e a comanda '
              'continua inteira na mesa ${widget.principal.titulo}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.35, color: T.inkMedio)),
        ],
      ),
    );
  }

  Widget _listaComCaixinhas() {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text('Desmarque as mesas que devem sair do grupo',
                style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _linhaFixa(widget.principal),
                  for (final m in widget.secundarias) _linhaComCaixinha(m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// a principal não pode sair: é ela que segura a comanda
  Widget _linhaFixa(Mesa m) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        child: Row(
          children: [
            Icon(Ico.cadeado, size: 17, color: T.fraco),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Mesa ${m.titulo}',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: T.ink)),
            ),
            Text('fica com a comanda',
                style: TextStyle(fontSize: 12, color: T.inkSoft)),
          ],
        ),
      );

  Widget _linhaComCaixinha(Mesa m) {
    final fica = _ficam.contains(m.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (fica) {
          _ficam.remove(m.id);
        } else {
          _ficam.add(m.id);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fica ? T.redDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border:
                    Border.all(color: fica ? T.redDark : T.borda, width: 1.8),
              ),
              child: fica
                  ? const Icon(Ico.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Mesa ${m.titulo}',
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: T.ink)),
            ),
            Text(fica ? 'continua junta' : 'vai separar',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: fica ? FontWeight.w500 : FontWeight.w800,
                    color: fica ? T.inkSoft : T.redDark)),
          ],
        ),
      ),
    );
  }
}
