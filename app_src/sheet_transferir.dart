import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';

/* ================================================================== *
 *  TRANSFERIR ITENS DE UMA MESA PARA OUTRA
 *
 *  O garçom marca os itens e escolhe a mesa de destino. Se levar
 *  todos, a mesa de origem fecha sozinha (é o servidor que faz isso).
 *
 *  Devolve true quando transferiu.
 * ================================================================== */
Future<bool?> mostrarTransferir(
  BuildContext context, {
  required Mesa origem,
  required List<ItemComanda> itens,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetTransferir(origem: origem, itens: itens),
  );
}

class _SheetTransferir extends StatefulWidget {
  final Mesa origem;
  final List<ItemComanda> itens;
  const _SheetTransferir({required this.origem, required this.itens});

  @override
  State<_SheetTransferir> createState() => _SheetTransferirState();
}

class _SheetTransferirState extends State<_SheetTransferir> {
  final Set<int> _escolhidos = {};
  Mesa? _destino;
  bool _levarIdentificacao = false;

  List<Mesa> _mesas = [];
  bool _carregandoMesas = true;
  bool _ocupado = false;
  String? _erro;

  /// depois de transferir: o que o servidor respondeu
  int? _movidos;
  bool _origemFechou = false;

  @override
  void initState() {
    super.initState();
    _buscarMesas();
  }

  Future<void> _buscarMesas() async {
    try {
      final r = await Api.mesas();
      if (!mounted) return;
      setState(() {
        _mesas = r
            .map(Mesa.fromJson)
            // a própria mesa e as secundárias de um grupo ficam de fora:
            // secundária não tem comanda, quem recebe é a principal
            .where((m) => m.id != widget.origem.id && !m.secundariaDoGrupo)
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));
        _carregandoMesas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _carregandoMesas = false);
    }
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  double get _valorEscolhido => widget.itens
      .where((i) => _escolhidos.contains(i.id))
      .fold(0.0, (soma, i) => soma + i.precoTotal);

  bool get _levaTudo => _escolhidos.length == widget.itens.length;

  bool get _podeEnviar =>
      _escolhidos.isNotEmpty && _destino != null && !_ocupado;

  Future<void> _enviar() async {
    if (!_podeEnviar) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final r = await Api.transferirItens(
        widget.origem.id,
        mesaDestino: _destino!.id,
        itens: _escolhidos.toList(),
        levarIdentificacao: _levarIdentificacao,
      );
      if (!mounted) return;

      final quantos = _int(r['movedCount']);
      if (quantos == 0) {
        // aceitou mas nao moveu nada: mostra em vez de fechar calado
        setState(() {
          _ocupado = false;
          _erro = 'O servidor aceitou mas não moveu nenhum item. '
              'Confira no painel antes de tentar de novo.';
        });
        return;
      }

      setState(() {
        _ocupado = false;
        _movidos = quantos;
        _origemFechou = r['sourceEmpty'] == true;
      });
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
        _erro = 'Não deu para transferir agora. Tente de novo.';
      });
    }
  }

  String _recado(ApiErro e) {
    switch (e.codigo) {
      case 'SOURCE_TAB_CLOSED':
        return 'Essa mesa já foi fechada.';
      case 'SAME_TABLE':
        return 'Escolha uma mesa diferente.';
      case 'TABLE_NOT_FOUND':
        return 'Essa mesa não existe mais. Puxe a tela para atualizar.';
      default:
        return e.mensagem;
    }
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: altura * .9),
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _movidos != null
          ? _confirmacao()
          : Column(
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
          const SizedBox(height: 16),
          _tituloPequeno('ITENS PARA LEVAR', acao: _botaoMarcarTudo()),
          Flexible(child: _listaDeItens()),
          const SizedBox(height: 14),
          _tituloPequeno('PARA QUAL MESA'),
          _escolhaDeMesa(),
          if (widget.origem.identificacao.isNotEmpty && _levaTudo) ...[
            const SizedBox(height: 12),
            _levarNome(),
          ],
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: T.redDark)),
          ],
          const SizedBox(height: 14),
          AfundaAoTocar(
            onTap: _podeEnviar ? _enviar : () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _podeEnviar ? kGradRed : null,
                color: _podeEnviar ? null : T.campo2,
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: _podeEnviar ? Colors.white : T.fraco)),
            ),
          ),
          if (_levaTudo && _escolhidos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                  'Levando tudo, a mesa ${widget.origem.titulo} '
                  'volta a ficar livre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: T.inkSoft)),
            ),
        ],
      ),
    );
  }

  String _textoDoBotao() {
    if (_escolhidos.isEmpty) return 'Marque os itens';
    if (_destino == null) return 'Escolha a mesa de destino';
    final n = _escolhidos.length;
    return 'Transferir $n ${n == 1 ? "item" : "itens"} '
        '· ${reais(_valorEscolhido)}';
  }

  /* ---------------- confirmação ---------------- */
  Widget _confirmacao() {
    final destino = _destino;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.greenSuave,
              shape: BoxShape.circle,
            ),
            child: Icon(Ico.check, size: 30, color: T.green),
          ),
        ),
        const SizedBox(height: 14),
        Text(
            '$_movidos ${_movidos == 1 ? "item transferido" : "itens transferidos"}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: T.ink,
                letterSpacing: -.4)),
        const SizedBox(height: 4),
        Text(
            'Da mesa ${widget.origem.titulo} para a mesa '
            '${destino == null ? "" : destino.titulo}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.3, color: T.inkSoft)),
        if (_origemFechou)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'A mesa ${widget.origem.titulo} ficou sem itens e voltou '
                'a ficar livre.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
          ),
        const SizedBox(height: 20),
        AfundaAoTocar(
          onTap: () => Navigator.of(context).pop(_origemFechou),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: kGradRed,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Pronto',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  /* ---------------- pedaços ---------------- */

  Widget _cabecalho() {
    final m = widget.origem;
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
          child: Text(m.principalDoGrupo ? m.tituloDoGrupo : m.titulo,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: T.redDark,
                  letterSpacing: -.4)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transferir itens',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      height: 1.15,
                      letterSpacing: -.4)),
              Text('Saindo da mesa ${m.titulo}',
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
    );
  }

  Widget _tituloPequeno(String texto, {Widget? acao}) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8, right: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(texto,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                      color: T.inkSoft)),
            ),
            if (acao != null) acao,
          ],
        ),
      );

  Widget _botaoMarcarTudo() => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          if (_levaTudo) {
            _escolhidos.clear();
            _levarIdentificacao = false;
          } else {
            _escolhidos
              ..clear()
              ..addAll(widget.itens.map((i) => i.id));
          }
        }),
        child: Text(_levaTudo ? 'Desmarcar' : 'Marcar tudo',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: T.redDark)),
      );

  Widget _listaDeItens() {
    if (widget.itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Nenhum item para transferir',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: T.inkSoft)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: widget.itens.length,
      separatorBuilder: (_, __) => Divider(color: T.line, height: 1),
      itemBuilder: (_, i) {
        final item = widget.itens[i];
        final marcado = _escolhidos.contains(item.id);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            if (marcado) {
              _escolhidos.remove(item.id);
              _levarIdentificacao = false;
            } else {
              _escolhidos.add(item.id);
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
                      Text('${item.quantidade}x ${item.nome}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: T.ink)),
                      if (item.complementos.isNotEmpty)
                        Text(item.complementos.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: T.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(reais(item.precoTotal),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _escolhaDeMesa() {
    if (_carregandoMesas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Espera(texto: 'Buscando as mesas...', tamanho: 13),
      );
    }
    if (_mesas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text('Nenhuma outra mesa no salão',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: T.inkSoft)),
      );
    }

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _mesas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _mesas[i];
          final ativa = _destino?.id == m.id;
          return AfundaAoTocar(
            onTap: () => setState(() => _destino = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ativa ? T.redSuave : T.campo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: ativa ? T.redDark : T.borda,
                    width: ativa ? 1.6 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(m.principalDoGrupo ? m.tituloDoGrupo : m.titulo,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ativa ? T.redDark : T.ink,
                          letterSpacing: -.3)),
                  const SizedBox(height: 2),
                  Text(m.pareceLivre ? 'livre' : 'ocupada',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: m.pareceLivre ? T.green : T.inkSoft)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// só faz sentido quando o cliente está mudando de mesa com tudo
  Widget _levarNome() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          setState(() => _levarIdentificacao = !_levarIdentificacao),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: T.campo,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: T.borda),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _levarIdentificacao ? T.redDark : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: _levarIdentificacao ? T.redDark : T.borda,
                    width: 1.8),
              ),
              child: _levarIdentificacao
                  ? const Icon(Ico.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                  'Levar a identificação "${widget.origem.identificacao}" '
                  'para a nova mesa',
                  style: TextStyle(
                      fontSize: 13, height: 1.3, color: T.inkMedio)),
            ),
          ],
        ),
      ),
    );
  }
}
