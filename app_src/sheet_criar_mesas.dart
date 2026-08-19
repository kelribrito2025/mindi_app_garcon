import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';

/* ================================================================== *
 *  MODAL "CRIAR MESAS"
 *  Cria um espaço novo (Salão, Varanda...) já com uma quantidade de
 *  mesas dentro. Devolve TRUE quando deu certo, para a tela recarregar.
 * ================================================================== */
Future<bool?> mostrarCriarMesas(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => const _SheetCriarMesas(),
  );
}

class _SheetCriarMesas extends StatefulWidget {
  const _SheetCriarMesas();

  @override
  State<_SheetCriarMesas> createState() => _SheetCriarMesasState();
}

class _SheetCriarMesasState extends State<_SheetCriarMesas> {
  final _nome = TextEditingController();
  final _quantidade = TextEditingController(text: '10');
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  int get _quantos => int.tryParse(_quantidade.text) ?? 0;

  bool get _podeCriar =>
      _nome.text.trim().length >= 2 && _quantos >= 1 && _quantos <= 100;

  Future<void> _criar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await Api.criarEspacoComMesas(
        nome: _nome.text.trim(),
        mesas: _quantos,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível criar as mesas.');
    } finally {
      if (mounted) setState(() => _salvando = false);
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
            // ---------- cabeçalho ----------
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
                  child: Icon(Ico.mesas, size: 23, color: T.redDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Criar mesas',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: T.ink,
                              letterSpacing: -.4)),
                      const SizedBox(height: 2),
                      Text('Um espaço novo com as mesas dentro',
                          style: TextStyle(fontSize: 13, color: T.inkSoft)),
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
            const SizedBox(height: 20),

            // ---------- nome do espaço ----------
            Text('Nome do espaço',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: T.rotulo)),
            const SizedBox(height: 8),
            TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              maxLength: 24,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 15.5, color: T.ink),
              decoration: _decoracao('Salão, Varanda, Terraço...'),
            ),
            const SizedBox(height: 14),

            // ---------- quantidade ----------
            Text('Quantas mesas',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: T.rotulo)),
            const SizedBox(height: 8),
            Row(
              children: [
                _passo(Ico.menosItem, _quantos > 1, () {
                  setState(() => _quantidade.text = '${_quantos - 1}');
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _quantidade,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: T.ink),
                    decoration: _decoracao('10'),
                  ),
                ),
                const SizedBox(width: 10),
                _passo(Ico.maisItem, _quantos < 100, () {
                  setState(() => _quantidade.text = '${_quantos + 1}');
                }),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _nome.text.trim().isEmpty || _quantos < 1
                  ? 'As mesas serão numeradas automaticamente, de 1 em diante.'
                  : 'Vai criar as mesas 1 a $_quantos em "${_nome.text.trim()}".',
              style: TextStyle(fontSize: 12.5, color: T.inkSoft, height: 1.4),
            ),

            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!,
                  style: TextStyle(fontSize: 12.5, color: T.redDark)),
            ],

            const SizedBox(height: 20),
            AfundaAoTocar(
              onTap: !_podeCriar || _salvando ? () {} : _criar,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _podeCriar ? kGradRed : null,
                  color: _podeCriar ? null : T.campo2,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Criar mesas',
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: _podeCriar ? Colors.white : T.fraco)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracao(String dica) => InputDecoration(
        hintText: dica,
        hintStyle: TextStyle(
            color: T.fraco, fontSize: 15.5, fontWeight: FontWeight.w400),
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
      );

  Widget _passo(IconData icone, bool ativo, VoidCallback onTap) {
    return AfundaAoTocar(
      onTap: ativo ? onTap : () {},
      child: Container(
        width: 50,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? T.campo : T.campo2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.borda),
        ),
        child: Icon(icone, size: 19, color: ativo ? T.ink : T.fraco),
      ),
    );
  }
}
