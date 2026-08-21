import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';

/* ================================================================== *
 *  MODAL "GERENCIAR SALÃO"
 *  Duas seções:
 *    - Espaços: mudar o nome
 *    - Mesas excluídas: trazer de volta
 *  Devolve TRUE quando alguma coisa mudou, para a tela recarregar.
 * ================================================================== */
Future<bool?> mostrarGerenciar(BuildContext context, List<Espaco> espacos) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetGerenciar(espacos: espacos),
  );
}

class _SheetGerenciar extends StatefulWidget {
  final List<Espaco> espacos;
  const _SheetGerenciar({required this.espacos});

  @override
  State<_SheetGerenciar> createState() => _SheetGerenciarState();
}

class _SheetGerenciarState extends State<_SheetGerenciar> {
  late List<Espaco> _espacos = List.of(widget.espacos);
  List<MesaExcluida> _lixeira = [];
  bool _carregandoLixeira = true;
  bool _mudou = false;

  /// id do espaço que está sendo renomeado agora
  int? _editando;
  final _nome = TextEditingController();
  bool _salvando = false;

  /// id da mesa que está sendo restaurada agora
  int? _restaurando;

  @override
  void initState() {
    super.initState();
    _carregarLixeira();
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _carregarLixeira() async {
    if (!apiConfigurada) {
      setState(() => _carregandoLixeira = false);
      return;
    }
    try {
      final r = await Api.mesasExcluidas();
      if (!mounted) return;
      setState(() => _lixeira = r.map(MesaExcluida.fromJson).toList());
    } catch (_) {
      // sem internet: a seção fica vazia
    } finally {
      if (mounted) setState(() => _carregandoLixeira = false);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.dark2,
    ));
  }

  /* ---------------- renomear espaço ---------------- */

  void _comecarEdicao(Espaco e) {
    setState(() {
      _editando = e.id;
      _nome.text = e.nome;
    });
  }

  Future<void> _salvarNome(Espaco e) async {
    final novo = _nome.text.trim();
    if (novo.length < 2 || novo == e.nome) {
      setState(() => _editando = null);
      return;
    }
    setState(() => _salvando = true);
    try {
      await Api.renomearEspaco(e.id, novo);
      if (!mounted) return;
      setState(() {
        _espacos = _espacos
            .map((x) => x.id == e.id
                ? Espaco(id: x.id, nome: novo, ordem: x.ordem, mesas: x.mesas)
                : x)
            .toList();
        _editando = null;
        _mudou = true;
      });
    } on ApiErro catch (erro) {
      if (mounted) _avisar(erro.mensagem);
    } catch (_) {
      if (mounted) _avisar('Não foi possível mudar o nome.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /* ---------------- restaurar mesa ---------------- */

  Future<void> _restaurar(MesaExcluida m) async {
    setState(() => _restaurando = m.id);
    try {
      final r = await Api.restaurarMesa(m.id);
      if (!mounted) return;
      setState(() {
        _lixeira = _lixeira.where((x) => x.id != m.id).toList();
        _mudou = true;
      });
      final numero = r['number'];
      if (r['renumbered'] == true && numero != null) {
        _avisar('Restaurada como Mesa $numero — '
            'o número ${m.numero} já estava em uso.');
      } else {
        _avisar('${m.titulo} restaurada.');
      }
    } on ApiErro catch (erro) {
      if (!mounted) return;
      if (erro.codigo == 'SPACE_INACTIVE') {
        _avisar('O espaço dessa mesa foi apagado. '
            'Recrie o espaço antes de restaurar.');
      } else {
        _avisar(erro.mensagem);
      }
    } catch (_) {
      if (mounted) _avisar('Não foi possível restaurar.');
    } finally {
      if (mounted) setState(() => _restaurando = null);
    }
  }

  /* ---------------- tela ---------------- */

  @override
  Widget build(BuildContext context) {
    final margem = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final altura = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: margem),
      child: Container(
        constraints: BoxConstraints(maxHeight: altura * .82),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
            _cabecalho(),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titulo('ESPAÇOS', '${_espacos.length}'),
                    if (_espacos.isEmpty)
                      _vazio('Nenhum espaço criado ainda.')
                    else
                      ..._espacos.map(_linhaEspaco),
                    const SizedBox(height: 20),
                    _titulo('MESAS EXCLUÍDAS', '${_lixeira.length}'),
                    if (_carregandoLixeira)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Espera(texto: 'Procurando...'),
                      )
                    else if (_lixeira.isEmpty)
                      _vazio('Nenhuma mesa excluída.')
                    else
                      ..._lixeira.map(_linhaExcluida),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.campo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Ico.ajustes, size: 23, color: T.inkMedio),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gerenciar salão',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      height: 1.15,
                      letterSpacing: -.4)),
              Text('Nomes dos espaços e mesas excluídas',
                  style: TextStyle(
                      fontSize: 13, height: 1.25, color: T.inkSoft)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(_mudou),
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

  Widget _titulo(String texto, String contagem) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
        child: Row(
          children: [
            Text(texto,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                    color: T.inkSoft)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: T.campo,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(contagem,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: T.inkSoft)),
            ),
          ],
        ),
      );

  Widget _vazio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(texto,
            style: TextStyle(fontSize: 13, color: T.fraco)),
      );

  Widget _caixa({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: T.campo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.borda),
        ),
        child: child,
      );

  /* ---------------- linha de espaço ---------------- */
  Widget _linhaEspaco(Espaco e) {
    final editando = _editando == e.id;

    if (editando) {
      return _caixa(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nome,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: T.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _salvarNome(e),
              ),
            ),
            const SizedBox(width: 8),
            AfundaAoTocar(
              onTap: _salvando ? () {} : () => _salvarNome(e),
              child: Container(
                width: 36,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: kGradRed,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Ico.check, size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _editando = null),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: Icon(Ico.fechar, size: 16, color: T.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    return _caixa(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
                if (e.mesas > 0)
                  Text('${e.mesas} ${e.mesas == 1 ? "mesa" : "mesas"}',
                      style: TextStyle(fontSize: 12, color: T.inkSoft)),
              ],
            ),
          ),
          AfundaAoTocar(
            onTap: () => _comecarEdicao(e),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: T.card,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: T.borda),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ico.editar, size: 14, color: T.inkMedio),
                  const SizedBox(width: 6),
                  Text('Renomear',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: T.inkMedio)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- linha da lixeira ---------------- */
  Widget _linhaExcluida(MesaExcluida m) {
    final ocupado = _restaurando == m.id;
    return _caixa(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.titulo,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
                Text(
                    [m.espacoNome, m.quando]
                        .where((t) => t.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(fontSize: 12, color: T.inkSoft)),
              ],
            ),
          ),
          AfundaAoTocar(
            onTap: ocupado ? () {} : () => _restaurar(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: T.greenSuave,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: T.greenBorda),
              ),
              child: ocupado
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: T.green),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Ico.voltarSeta, size: 14, color: T.greenEscuro),
                        const SizedBox(width: 6),
                        Text('Restaurar',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: T.greenEscuro)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
