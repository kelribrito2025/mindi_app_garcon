import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';
import 'cardapio.dart';
import 'sessao.dart';
import 'sheets_pedido.dart';

/* ================================================================== *
 *  MODAL "LANÇAR ITENS"
 *  Abre por cima do modal da mesa. O garçom busca o produto, monta a
 *  lista e envia — com ou sem impressão.
 *  Devolve TRUE quando algum item foi enviado.
 * ================================================================== */
Future<bool?> mostrarLancarItens(
  BuildContext context, {
  required Mesa mesa,
  required int comandaId,
  required double totalAtual,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetLancar(
      mesa: mesa,
      comandaId: comandaId,
      totalAtual: totalAtual,
    ),
  );
}

class _SheetLancar extends StatefulWidget {
  final Mesa mesa;
  final int comandaId;
  final double totalAtual;
  const _SheetLancar({
    required this.mesa,
    required this.comandaId,
    required this.totalAtual,
  });

  @override
  State<_SheetLancar> createState() => _SheetLancarState();
}

class _SheetLancarState extends State<_SheetLancar> {
  final _busca = TextEditingController();
  final _foco = FocusNode();
  final List<ItemNovo> _carrinho = [];

  bool _carregandoCardapio = true;
  bool _enviando = false;
  String _identificacao = '';

  @override
  void initState() {
    super.initState();
    _identificacao = widget.mesa.identificacao;
    _carregarCardapio();
  }

  @override
  void dispose() {
    _busca.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _carregarCardapio() async {
    try {
      await Cardapio.carregar();
    } catch (_) {
      // sem internet: a busca fica vazia e o aviso aparece na tela
    } finally {
      if (mounted) setState(() => _carregandoCardapio = false);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.dark2,
    ));
  }

  /* ---------------- contas ---------------- */

  double get _subtotal =>
      _carrinho.fold(0.0, (soma, i) => soma + i.total);

  double get _taxa => _subtotal * (Sessao.taxaServico / 100);

  double get _total => _subtotal + _taxa;

  /* ---------------- montar a lista ---------------- */

  Future<void> _adicionar(Produto p) async {
    final grupos = Cardapio.gruposDe(p.id);

    Map<OpcaoComplemento, int>? extras;
    if (p.temComplementos && grupos.isNotEmpty) {
      extras = await mostrarComplementos(context, produto: p, grupos: grupos);
      if (extras == null) return; // cancelou
    }

    setState(() {
      // item igual (mesmo produto, mesmos complementos) só soma quantidade
      final igual = _carrinho.where((i) =>
          i.produto.id == p.id &&
          i.nomesDosExtras.join('|') ==
              ItemNovo(produto: p, extras: extras).nomesDosExtras.join('|'));
      if (igual.isNotEmpty) {
        igual.first.quantidade++;
      } else {
        _carrinho.add(ItemNovo(produto: p, extras: extras));
      }
      _busca.clear();
    });
    _foco.requestFocus();
  }

  void _mudarQuantidade(ItemNovo item, int passo) {
    setState(() {
      item.quantidade += passo;
      if (item.quantidade <= 0) _carrinho.remove(item);
    });
  }

  /* ---------------- identificação ---------------- */

  Future<void> _identificar() async {
    final novo = await mostrarIdentificacao(context, atual: _identificacao);
    if (novo == null || !mounted) return;
    try {
      await Api.identificarMesa(widget.mesa.id, novo);
      if (mounted) setState(() => _identificacao = novo);
    } on ApiErro catch (e) {
      if (mounted) _avisar(e.mensagem);
    } catch (_) {
      if (mounted) _avisar('Não foi possível salvar a identificação.');
    }
  }

  /* ---------------- enviar ---------------- */

  Future<void> _lancar() async {
    if (_carrinho.isEmpty) return;

    final escolha = await mostrarEnviarPedido(context, itens: _carrinho.length);
    if (escolha == null || !mounted) return;

    setState(() => _enviando = true);
    try {
      await Api.adicionarItens(
        widget.comandaId,
        _carrinho.map((i) => i.paraApi()).toList(),
      );

      if (escolha == 'imprimir') {
        try {
          await Api.imprimirComanda(widget.comandaId);
        } on ApiErro catch (e) {
          // os itens já estão na comanda; só a impressão falhou
          if (mounted) {
            _avisar(e.codigo == 'PRINTER_OFFLINE'
                ? 'Itens enviados, mas a impressora não respondeu.'
                : 'Itens enviados, mas não imprimiu: ${e.mensagem}');
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (e.codigo == 'TAB_MODIFIED') {
        _avisar('Outra pessoa mexeu nesta comanda. Confira antes de enviar.');
        Navigator.of(context).pop(true);
        return;
      }
      _avisar(e.mensagem);
    } catch (_) {
      if (mounted) _avisar('Não foi possível enviar os itens.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _historico() async {
    await mostrarHistoricoDaMesa(context, mesa: widget.mesa);
  }

  /* ---------------- tela ---------------- */

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final altura = MediaQuery.of(context).size.height;
    final achados = Cardapio.buscar(_busca.text);

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: Container(
        constraints: BoxConstraints(maxHeight: altura * .9),
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
            _cabecalho(),
            const SizedBox(height: 14),
            _campoBusca(),
            const SizedBox(height: 12),
            Flexible(
              child: achados.isNotEmpty
                  ? _listaDeProdutos(achados)
                  : _listaDoCarrinho(),
            ),
            if (achados.isEmpty) ...[
              const SizedBox(height: 12),
              _totais(),
              const SizedBox(height: 14),
              _botoes(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    final m = widget.mesa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.redSuave,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(m.titulo,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: T.redDark)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nome.isNotEmpty ? m.nome : 'Mesa ${m.titulo}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                          height: 1.15,
                          letterSpacing: -.4)),
                  Text('já na mesa',
                      style: TextStyle(
                          fontSize: 12.5, height: 1.25, color: T.inkSoft)),
                ],
              ),
            ),
            Text(reais(widget.totalAtual),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                    letterSpacing: -.4)),
            const SizedBox(width: 10),
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
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _identificar,
          child: Row(
            children: [
              Icon(_identificacao.isEmpty ? Ico.maisItem : Ico.editar,
                  size: 14, color: T.redDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                    _identificacao.isEmpty
                        ? 'Adicionar identificação'
                        : _identificacao,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: T.redDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _campoBusca() {
    return TextField(
      controller: _busca,
      focusNode: _foco,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
      style: TextStyle(fontSize: 15.5, color: T.ink),
      decoration: InputDecoration(
        hintText: _carregandoCardapio
            ? 'Carregando o cardápio...'
            : 'Buscar produto',
        hintStyle: TextStyle(color: T.fraco),
        prefixIcon: Icon(Ico.busca, size: 19, color: T.fraco),
        suffixIcon: _busca.text.isEmpty
            ? null
            : GestureDetector(
                onTap: () => setState(() => _busca.clear()),
                child: Icon(Ico.fechar, size: 17, color: T.inkSoft),
              ),
        filled: true,
        fillColor: T.campo,
        isDense: true,
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
    );
  }

  /* ---------------- lista da busca ---------------- */
  Widget _listaDeProdutos(List<Produto> achados) {
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: achados.length,
      separatorBuilder: (_, __) => Divider(color: T.line, height: 1),
      itemBuilder: (_, i) {
        final p = achados[i];
        return AfundaAoTocar(
          onTap: () => _adicionar(p),
          escala: .98,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: T.ink)),
                      Text(
                          [
                            Cardapio.nomeDaCategoria(p.categoriaId),
                            if (p.temComplementos) 'tem opções',
                          ].where((t) => t.isNotEmpty).join(' · '),
                          style: TextStyle(fontSize: 12, color: T.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(reais(p.precoValendo),
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
                const SizedBox(width: 10),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: kGradRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Ico.maisItem,
                      size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /* ---------------- lista do carrinho ---------------- */
  Widget _listaDoCarrinho() {
    if (_busca.text.isNotEmpty && !_carregandoCardapio) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(Ico.busca, size: 30, color: T.fraco),
            const SizedBox(height: 10),
            Text('Nenhum produto com "${_busca.text}"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: T.inkSoft)),
          ],
        ),
      );
    }

    if (_carrinho.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Icon(Ico.cardapio, size: 32, color: T.fraco),
            const SizedBox(height: 10),
            Text('Nenhum item ainda',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: T.ink)),
            const SizedBox(height: 4),
            Text('Use a busca acima para adicionar ao pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: _carrinho.length,
      separatorBuilder: (_, __) => Divider(color: T.line, height: 1),
      itemBuilder: (_, i) {
        final item = _carrinho[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.produto.nome,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: T.ink)),
                    if (item.nomesDosExtras.isNotEmpty)
                      Text(item.nomesDosExtras.join(', '),
                          style:
                              TextStyle(fontSize: 12, color: T.inkSoft)),
                  ],
                ),
              ),
              _passo(Ico.menosItem, () => _mudarQuantidade(item, -1)),
              SizedBox(
                width: 34,
                child: Text('${item.quantidade}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ),
              _passo(Ico.maisItem, () => _mudarQuantidade(item, 1)),
              SizedBox(
                width: 74,
                child: Text(reais(item.total),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _passo(IconData icone, VoidCallback onTap) => AfundaAoTocar(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.campo,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: T.borda),
          ),
          child: Icon(icone, size: 15, color: T.inkMedio),
        ),
      );

  /* ---------------- totais e botões ---------------- */
  Widget _totais() {
    if (_carrinho.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: T.campo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: T.borda),
      ),
      child: Column(
        children: [
          _linha('Subtotal', _subtotal),
          if (Sessao.taxaServico > 0)
            _linha(
                'Taxa de serviço (${Sessao.taxaServico.toStringAsFixed(0)}%)',
                _taxa),
          const SizedBox(height: 5),
          Divider(color: T.line, height: 1),
          const SizedBox(height: 7),
          _linha('Total', _total, forte: true),
        ],
      ),
    );
  }

  Widget _linha(String rotulo, double valor, {bool forte = false}) => Padding(
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
                    fontWeight: forte ? FontWeight.w800 : FontWeight.w700,
                    color: forte ? T.ink : T.inkMedio)),
          ],
        ),
      );

  Widget _botoes() {
    final podeEnviar = _carrinho.isNotEmpty && !_enviando;
    return Row(
      children: [
        Expanded(
          child: AfundaAoTocar(
            onTap: _historico,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.campo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.borda),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ico.historico, size: 16, color: T.inkMedio),
                  const SizedBox(width: 8),
                  Text('Histórico',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: T.inkMedio)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AfundaAoTocar(
            onTap: podeEnviar ? _lancar : () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: podeEnviar ? kGradRed : null,
                color: podeEnviar ? null : T.campo2,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _carrinho.isEmpty
                          ? 'Lançar itens'
                          : 'Lançar ${_carrinho.length} '
                              '${_carrinho.length == 1 ? "item" : "itens"}',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: podeEnviar ? Colors.white : T.fraco)),
            ),
          ),
        ),
      ],
    );
  }
}
