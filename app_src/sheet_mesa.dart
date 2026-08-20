import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';
import 'modelos.dart';
import 'sessao.dart';
import 'sheet_fechar.dart';
import 'sheet_pagamentos.dart';
import 'sheet_transferir.dart';
import 'sheet_lancar_itens.dart';

/* ================================================================== *
 *  MODAL DA MESA
 *  Mesa livre  -> abrir mesa (quantas pessoas)
 *  Mesa aberta -> ver a comanda, pedir a conta, fechar a mesa
 *
 *  Devolve TRUE quando alguma coisa mudou, para a tela de trás
 *  recarregar o mapa na hora.
 * ================================================================== */
Future<bool?> mostrarMesa(BuildContext context, Mesa mesa) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (_) => _SheetMesa(mesa: mesa),
  );
}

class _SheetMesa extends StatefulWidget {
  final Mesa mesa;
  const _SheetMesa({required this.mesa});

  @override
  State<_SheetMesa> createState() => _SheetMesaState();
}

class _SheetMesaState extends State<_SheetMesa> {
  Comanda? _comanda;
  Mesa? _detalhe;
  bool _carregando = true;
  bool _ocupado = false; // alguma ação em andamento
  bool _mudou = false;
  String? _erro;

  int _pessoas = 1;

  @override
  void initState() {
    super.initState();
    _pessoas = widget.mesa.pessoas > 0 ? widget.mesa.pessoas : 1;
    _carregar();
  }

  Mesa get _mesa => _detalhe ?? widget.mesa;

  Future<void> _carregar() async {
    if (!apiConfigurada) {
      setState(() => _carregando = false);
      return;
    }
    setState(() => _carregando = true);
    try {
      final r = await Api.mesa(widget.mesa.id);
      if (!mounted) return;
      final t = r['table'];
      final c = r['tab'];
      setState(() {
        if (t is Map) _detalhe = Mesa.fromJson(t.cast<String, dynamic>());
        _comanda =
            c is Map ? Comanda.fromJson(c.cast<String, dynamic>()) : null;
        _erro = null;
      });
    } on ApiErro catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível abrir a mesa.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      backgroundColor: T.dark2,
    ));
  }

  /* ---------------- ações ---------------- */

  Future<void> _abrir() async {
    setState(() => _ocupado = true);
    try {
      final r = await Api.abrirMesa(widget.mesa.id, pessoas: _pessoas);
      _mudou = true;
      if (!mounted) return;
      if (r['alreadyOpen'] == true) {
        _avisar('Essa mesa já estava aberta.');
      }
      await _carregar();
    } on ApiErro catch (e) {
      if (!mounted) return;
      // outro garçom abriu primeiro: mostra a comanda que já existe
      if (e.codigo == 'TABLE_ALREADY_OPEN') {
        _mudou = true;
        _avisar('Outro garçom abriu essa mesa. Mostrando a comanda.');
        await _carregar();
      } else {
        _avisar(e.mensagem);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _lancarItens() async {
    final comanda = _comanda;
    if (comanda == null || comanda.id == 0) {
      _avisar('Comanda ainda não carregou. Tente de novo.');
      return;
    }
    final enviou = await mostrarLancarItens(
      context,
      mesa: _mesa,
      comandaId: comanda.id,
      totalAtual: comanda.total,
    );
    if (enviou == true && mounted) {
      _mudou = true;
      _avisar('Itens lançados na mesa');
      await _carregar();
    }
  }

  Future<void> _pedirConta() async {
    setState(() => _ocupado = true);
    try {
      await Api.pedirConta(_mesa.id);
      _mudou = true;
      if (!mounted) return;
      _avisar('Conta solicitada.');
      await _carregar();
    } on ApiErro catch (e) {
      if (mounted) _avisar(e.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Botão "Solicitar conta": escolhe entre avisar o balcão ou fechar
  Future<void> _abrirOpcoesDaConta() async {
    final escolha = await mostrarOpcoesDaConta(
      context,
      mesa: _mesa.titulo,
      contaJaPedida: _mesa.pedindoConta,
    );
    if (escolha == null || !mounted) return;
    if (escolha == 'solicitar') {
      await _pedirConta();
    } else if (escolha == 'parcial') {
      await _fecharParcial();
    } else if (escolha == 'avulso') {
      await _pagamentoAvulso();
    } else if (escolha == 'fechar') {
      await _fechar();
    }
  }

  /// leva itens desta mesa para outra
  Future<void> _transferir() async {
    final itens =
        _comanda?.itens.where((i) => !i.cancelado).toList() ?? const [];
    if (itens.isEmpty) {
      _avisar('Não há itens para transferir.');
      return;
    }
    // devolve true quando a mesa de origem ficou vazia e o servidor
    // fechou ela; false quando ainda sobrou item; null quando cancelou
    final fechou = await mostrarTransferir(
      context,
      origem: _mesa,
      itens: itens,
    );
    if (fechou == null || !mounted) return;

    _mudou = true;
    _avisar('Itens transferidos.');
    if (fechou) {
      // a mesa não existe mais como aberta: sai do modal
      Navigator.of(context).pop(true);
    } else {
      await _carregar();
    }
  }

  String get _nomeDaMesa =>
      _mesa.principalDoGrupo ? _mesa.tituloDoGrupo : _mesa.titulo;

  /// o cliente paga só os itens dele e vai embora
  Future<void> _fecharParcial() async {
    final itens =
        _comanda?.itens.where((i) => !i.cancelado).toList() ?? const [];
    if (itens.isEmpty) {
      _avisar('Não há itens para pagar nessa mesa.');
      return;
    }
    final feito = await mostrarFecharParcial(
      context,
      mesaId: _mesa.id,
      mesa: _nomeDaMesa,
      itens: itens,
    );
    if (feito == true && mounted) {
      _mudou = true;
      _avisar('Pagamento registrado.');
      await _carregar();
    }
  }

  /// abate um valor do saldo, sem escolher item
  Future<void> _pagamentoAvulso() async {
    final saldo = _comanda?.falta ?? 0;
    if (saldo <= 0) {
      _avisar('Essa mesa não tem saldo em aberto.');
      return;
    }
    final feito = await mostrarPagamentoAvulso(
      context,
      mesaId: _mesa.id,
      mesa: _nomeDaMesa,
      saldo: saldo,
    );
    if (feito == true && mounted) {
      _mudou = true;
      _avisar('Pagamento registrado.');
      await _carregar();
    }
  }

  Future<void> _fechar() async {
    final total = _comanda?.falta ?? 0;
    final resultado = await mostrarFechamento(context,
        total: total,
        mesa: _mesa.principalDoGrupo ? _mesa.tituloDoGrupo : _mesa.titulo);
    if (resultado == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await Api.fecharMesa(
        _mesa.id,
        formaPagamento: resultado.forma,
        valorPago: resultado.pago,
        troco: resultado.troco,
      );
      _mudou = true;
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _avisar('Mesa ${_mesa.titulo} fechada.');
    } on ApiErro catch (e) {
      if (!mounted) return;
      if (e.codigo == 'TABLE_ALREADY_CLOSED') {
        _mudou = true;
        Navigator.of(context).pop(true);
        _avisar('Essa mesa já tinha sido fechada.');
      } else {
        _avisar(e.mensagem);
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /* ---------------- separar mesas ---------------- */

  bool _separando = false;

  Future<void> _separar() async {
    setState(() => _separando = true);
    try {
      // manda a própria mesa: o servidor tira ela do grupo
      await Api.separarMesa(_mesa.id);
      _mudou = true;
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _avisar('Mesas separadas.');
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() => _separando = false);
      if (e.codigo == 'TABLE_NOT_MERGED') {
        _avisar('Essa mesa já não estava junta com outra.');
      } else if (e.codigo == 'TABLE_NOT_FOUND') {
        _avisar('Essa mesa não existe mais.');
      } else {
        _avisar(e.mensagem);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _separando = false);
      _avisar('Não deu para separar agora. Tente de novo.');
    }
  }

  /* ---------------- tela ---------------- */

  @override
  Widget build(BuildContext context) {
    final margem = MediaQuery.of(context).padding.bottom;
    final altura = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_mudou);
        return false;
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: altura * .88),
        padding: EdgeInsets.fromLTRB(18, 18, 18, 16 + margem),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecalho(),
            const SizedBox(height: 16),
            // Flexible só faz sentido quando o conteúdo pode passar da
            // tela (a comanda). No formulário de abrir, ele esticaria à toa.
            if (_mesa.livre || _carregando || _erro != null)
              _corpo()
            else
              Flexible(child: _corpo()),
            const SizedBox(height: 14),
            _botoes(),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() {
    final m = _mesa;
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: m.livre ? T.greenSuave : T.redSuave,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Ico.mesa,
              size: 23, color: m.livre ? T.green : T.redDark),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  m.principalDoGrupo
                      ? 'Mesa ${m.tituloDoGrupo}'
                      : (m.nome.isNotEmpty ? m.nome : 'Mesa ${m.titulo}'),
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      height: 1.15,
                      letterSpacing: -.4)),
              Text(_legenda(),
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

  String _legenda() {
    final m = _mesa;
    if (m.livre) return 'Livre';
    final partes = <String>[];
    if (m.principalDoGrupo) {
      partes.add(m.mesasJuntadas.length == 1
          ? 'junta com a mesa ${m.mesasJuntadas.first}'
          : 'junta com ${m.mesasJuntadas.length} mesas');
    }
    if (m.pessoas > 0) partes.add('${m.pessoas} pessoas');
    if (m.tempoAberta.isNotEmpty) partes.add('aberta há ${m.tempoAberta}');
    if (m.identificacao.isNotEmpty) partes.add(m.identificacao);
    return partes.join(' · ');
  }

  Widget _corpo() {
    if (_carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Espera(texto: 'Carregando a mesa...'),
      );
    }

    if (_erro != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(_erro!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: T.redDark)),
      );
    }

    if (_mesa.livre) return _formularioAbrir();
    return _comandaNaTela();
  }

  /* ---------------- mesa livre ---------------- */
  Widget _formularioAbrir() {
    return Column(
      // sem isso a coluna estica e o modal fica alto demais
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Quantas pessoas?',
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: T.rotulo)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: T.campo,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: T.borda),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botaoRedondo(Ico.menosItem, _pessoas > 1,
                  () => setState(() => _pessoas--)),
              SizedBox(
                width: 90,
                child: Text('$_pessoas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: T.ink,
                        letterSpacing: -1)),
              ),
              _botaoRedondo(Ico.maisItem, _pessoas < 30,
                  () => setState(() => _pessoas++)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botaoRedondo(IconData icone, bool ativo, VoidCallback onTap) {
    return AfundaAoTocar(
      onTap: ativo ? onTap : () {},
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ativo ? T.card : T.campo2,
          shape: BoxShape.circle,
          border: Border.all(color: T.borda),
        ),
        child: Icon(icone, size: 19, color: ativo ? T.ink : T.fraco),
      ),
    );
  }

  /* ---------------- mesa aberta ---------------- */
  Widget _comandaNaTela() {
    final c = _comanda;
    if (c == null || c.itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          // ocupa o espaço livre do modal e centraliza o aviso nele
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Ico.comanda, size: 34, color: T.fraco),
            const SizedBox(height: 10),
            Text('Nenhum item lançado ainda',
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: T.ink)),
            const SizedBox(height: 4),
            Text('Toque em "Lançar itens" para começar o pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final i in c.itens.where((e) => !e.cancelado)) _linhaItem(i),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.campo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.borda),
            ),
            child: Column(
              children: [
                _linhaTotal('Subtotal', c.subtotal),
                if (c.taxaServico > 0)
                  _linhaTotal(
                      'Taxa de serviço (${Sessao.taxaServico.toStringAsFixed(0)}%)',
                      c.taxaServico),
                if (c.desconto > 0) _linhaTotal('Desconto', -c.desconto),
                const SizedBox(height: 6),
                Divider(color: T.line, height: 1),
                const SizedBox(height: 8),
                _linhaTotal('Total', c.total, forte: true),
                if (c.pago > 0) ...[
                  _linhaTotal('Já pago', c.pago, cor: T.green),
                  _linhaTotal('Falta', c.falta, forte: true, cor: T.redDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaItem(ItemComanda i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // fundo claro, número escuro: verde quando o item já saiu
              // da cozinha, vermelho enquanto não saiu
              color: i.pronto ? T.greenSuave : T.redSuave,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text('${i.quantidade}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: i.pronto ? T.greenEscuro : T.redDark)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.nome,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
                if (i.complementos.isNotEmpty)
                  Text(i.complementos.join(', '),
                      style: TextStyle(fontSize: 12, color: T.inkSoft)),
                if (i.observacao.isNotEmpty)
                  Text(i.observacao,
                      style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: T.inkSoft)),
                if (i.situacao.isNotEmpty)
                  Text(i.situacao,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                          color: i.pronto ? T.green : T.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(reais(i.precoTotal),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: T.ink)),
        ],
      ),
    );
  }

  Widget _linhaTotal(String rotulo, double valor,
      {bool forte = false, Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo,
              style: TextStyle(
                  fontSize: forte ? 14.5 : 13,
                  fontWeight: forte ? FontWeight.w800 : FontWeight.w500,
                  color: cor ?? (forte ? T.ink : T.inkSoft))),
          Text(reais(valor),
              style: TextStyle(
                  fontSize: forte ? 16 : 13,
                  fontWeight: forte ? FontWeight.w800 : FontWeight.w700,
                  color: cor ?? (forte ? T.ink : T.inkMedio))),
        ],
      ),
    );
  }

  /* ---------------- botões de baixo ---------------- */
  Widget _botoes() {
    if (_carregando) return const SizedBox.shrink();

    if (_mesa.livre) {
      return _BotaoGrande(
        texto: 'Abrir mesa',
        icone: Ico.maisItem,
        carregando: _ocupado,
        onTap: _abrir,
      );
    }

    // "Pedir conta" e "Fechar mesa" só fazem sentido quando existe
    // alguma coisa lançada. Mesa recém-aberta só precisa de "Lançar itens".
    final temItens =
        _comanda?.itens.where((i) => !i.cancelado).isNotEmpty ?? false;

    return Column(
      children: [
        // os dois lado a lado: sobra espaço e cabe mais item na tela
        Row(
          children: [
            Expanded(
              flex: temItens ? 3 : 1,
              child: _BotaoGrande(
                texto: 'Lançar itens',
                icone: Ico.cardapio,
                carregando: false,
                onTap: _lancarItens,
              ),
            ),
            if (temItens) ...[
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                // dentro dele o garçom escolhe entre avisar o balcão,
                // pagar parcial, avulso ou fechar a mesa
                child: _BotaoGrande(
                  texto: 'Conta',
                  icone: Ico.conta,
                  secundario: true,
                  carregando: _ocupado,
                  onTap: _ocupado ? null : _abrirOpcoesDaConta,
                ),
              ),
              const SizedBox(width: 9),
              // só o ícone: leva itens desta mesa para outra
              _BotaoGrande(
                texto: '',
                icone: Ico.transferir,
                secundario: true,
                carregando: false,
                onTap: _ocupado ? null : _transferir,
              ),
            ],
          ],
        ),
        if (_mesa.principalDoGrupo) ...[
          const SizedBox(height: 9),
          _BotaoGrande(
            texto: 'Separar mesas',
            icone: Ico.separar,
            secundario: true,
            carregando: _separando,
            onTap: _ocupado ? null : _separar,
          ),
        ],
      ],
    );
  }
}

/* ================================================================== *
 *  BOTÃO GRANDE
 * ================================================================== */
class _BotaoGrande extends StatelessWidget {
  final String texto;
  final IconData icone;
  final bool secundario;
  final bool carregando;
  final VoidCallback? onTap;

  const _BotaoGrande({
    required this.texto,
    required this.icone,
    required this.carregando,
    required this.onTap,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    final desligado = onTap == null;
    return AfundaAoTocar(
      onTap: desligado || carregando ? () {} : onTap!,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: 15, horizontal: texto.isEmpty ? 16 : 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: secundario ? null : kGradRed,
          color: secundario ? T.campo : null,
          borderRadius: BorderRadius.circular(16),
          border: secundario ? Border.all(color: T.borda) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (carregando)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: secundario ? T.inkMedio : Colors.white),
              )
            else
              Icon(icone,
                  size: 17,
                  color: secundario
                      ? (desligado ? T.fraco : T.inkMedio)
                      : Colors.white),
            // botão só de ícone: sem texto, sem o espaço do texto
            if (texto.isNotEmpty) ...[
              const SizedBox(width: 9),
              Flexible(
                child: Text(texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: secundario
                            ? (desligado ? T.fraco : T.inkMedio)
                            : Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
