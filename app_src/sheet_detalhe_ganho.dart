import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';
import 'modelos.dart';

/* ================================================================== *
 *  DETALHE DE UMA MESA NA ABA GANHOS
 *  Mostra o total da mesa, a comissão e cada pagamento que entrou
 *  (avulsos e o fechamento), com forma, hora e observação.
 * ================================================================== */
Future<void> mostrarDetalheDaMesa(
  BuildContext context,
  ComandaDoGarcom comanda,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(.55),
    builder: (ctx) => _SheetDetalhe(comanda: comanda),
  );
}

class _SheetDetalhe extends StatelessWidget {
  final ComandaDoGarcom comanda;
  const _SheetDetalhe({required this.comanda});

  @override
  Widget build(BuildContext context) {
    final c = comanda;
    final altura = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: altura * .85),
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 18 + MediaQuery.of(context).padding.bottom),
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
                constraints: const BoxConstraints(minWidth: 50),
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.redSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: c.mesa.isEmpty
                    ? Icon(Ico.mesa, size: 23, color: T.redDark)
                    : Text(c.mesa,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: c.mesa.length > 2 ? 15 : 19,
                            fontWeight: FontWeight.w800,
                            color: T.redDark,
                            letterSpacing: -.4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.titulo,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: T.ink,
                            height: 1.15,
                            letterSpacing: -.4)),
                    Text(
                        [
                          if (c.identificacao.isNotEmpty) c.identificacao,
                          if (c.quando.isNotEmpty) c.quando,
                        ].join(' · '),
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
          ),
          const SizedBox(height: 18),

          // tudo que vem daqui para baixo rola junto: com muitos
          // pagamentos a lista sozinha esticava e desalinhava as linhas
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // total da mesa e a comissão
                  Row(
                    children: [
                      Expanded(
                        child: _Caixa(
                          rotulo: 'Total da mesa',
                          valor: reais(c.total),
                          cor: T.ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Caixa(
                          rotulo: 'Sua comissão',
                          valor: reais(c.comissao),
                          cor: T.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text('PAGAMENTOS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                            color: T.inkSoft)),
                  ),
                  _listaDePagamentos(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaDePagamentos() {
    final c = comanda;

    if (c.pagamentos.isEmpty) {
      // sem avulsos: a mesa foi paga de uma vez no fechamento
      return _linha(
        icone: _icone(c.formaDoFechamento),
        titulo: formaPagamento(c.formaDoFechamento),
        detalhe: 'Pagamento no fechamento',
        valor: c.total,
        ultima: true,
      );
    }

    final faltou = c.total - c.totalAvulso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          for (final p in c.pagamentos)
            _linha(
              icone: _icone(p.forma),
              titulo: p.formaBonita,
              detalhe: [
                if (p.hora.isNotEmpty) p.hora,
                if (p.observacao.isNotEmpty) p.observacao,
                if (p.registradoPor.isNotEmpty) 'por ${p.registradoPor}',
              ].join(' · '),
              valor: p.valor,
              ultima: false,
            ),
          if (faltou > 0.009)
            _linha(
              icone: _icone(c.formaDoFechamento),
              titulo: formaPagamento(c.formaDoFechamento),
              detalhe: 'Pagamento no fechamento',
              valor: faltou,
              ultima: true,
            ),
      ],
    );
  }

  IconData _icone(String forma) {
    switch (formaPagamento(forma)) {
      case 'Dinheiro':
        return Ico.conta;
      case 'PIX':
        return Ico.pix;
      case 'Cartão':
        return Ico.cartao;
      default:
        return Ico.recibo;
    }
  }

  Widget _linha({
    required IconData icone,
    required String titulo,
    required String detalhe,
    required double valor,
    required bool ultima,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: ultima ? null : Border(bottom: BorderSide(color: T.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.campo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, size: 17, color: T.inkMedio),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
                if (detalhe.isNotEmpty)
                  Text(detalhe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: T.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(reais(valor),
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: T.ink)),
        ],
      ),
    );
  }
}

class _Caixa extends StatelessWidget {
  final String rotulo, valor;
  final Color cor;
  const _Caixa({required this.rotulo, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: T.campo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo,
                style: TextStyle(fontSize: 12, color: T.inkSoft)),
            const SizedBox(height: 3),
            Text(valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cor,
                    letterSpacing: -.4)),
          ],
        ),
      );
}
