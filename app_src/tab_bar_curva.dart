import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';

/* ================================================================== *
 *  TAB BAR CURVA — barra branca flutuante com entalhe e bolha
 * ================================================================== */
class ItemAba {
  final String label;
  final IconData icone;
  const ItemAba(this.label, this.icone);
}

const kAbas = [
  ItemAba('Mesas', Ico.mesas),
  ItemAba('Cozinha', Ico.cozinha),
  ItemAba('Perfil', Ico.perfil),
];

class TabBarCurva extends StatefulWidget {
  final int indice;
  final ValueChanged<int> aoTrocar;
  const TabBarCurva({super.key, required this.indice, required this.aoTrocar});

  @override
  State<TabBarCurva> createState() => _TabBarCurvaState();
}

class _TabBarCurvaState extends State<TabBarCurva>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );
  late double _de = widget.indice.toDouble();
  late double _para = widget.indice.toDouble();

  @override
  void didUpdateWidget(covariant TabBarCurva old) {
    super.didUpdateWidget(old);
    if (old.indice != widget.indice) {
      _de = _posAtual();
      _para = widget.indice.toDouble();
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _posAtual() {
    final t = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0).toDouble());
    return _de + (_para - _de) * t;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final larguraAba = w / kAbas.length;

        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final cx = larguraAba * _posAtual() + larguraAba / 2;

            return SizedBox(
              height: kBarH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(size: Size(w, kBarH), painter: _PintorBarra(cx)),

                  Row(
                    children: List.generate(kAbas.length, (i) {
                      final ativo = i == widget.indice;
                      return SizedBox(
                        width: larguraAba,
                        height: kBarH,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.aoTrocar(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!ativo) ...[
                                Icon(kAbas[i].icone, size: 23, color: T.tabOff),
                                const SizedBox(height: 4),
                              ] else
                                const SizedBox(height: 22),
                              Text(
                                kAbas[i].label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight:
                                      ativo ? FontWeight.w700 : FontWeight.w600,
                                  color: ativo ? T.redDark : T.tabOff,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  // bolha flutuante do item ativo
                  Positioned(
                    left: cx - (kBubble + 12) / 2,
                    top: -(kBubble / 2) - 6,
                    child: Container(
                      width: kBubble + 12,
                      height: kBubble + 12,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: T.bg, shape: BoxShape.circle),
                      child: Container(
                        width: kBubble,
                        height: kBubble,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: kGradRed,
                          boxShadow: [
                            BoxShadow(
                              color: T.redDark.withOpacity(.42),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(kAbas[widget.indice].icone,
                            size: 25, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PintorBarra extends CustomPainter {
  final double cx;
  _PintorBarra(this.cx);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const r = kBarR, nr = kNotchR;
    const nw = nr * 1.2;
    final double c = cx.clamp(r + nw, w - r - nw).toDouble();

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(c - nw, 0)
      ..cubicTo(c - nw * 0.55, 0, c - nr * 0.78, nr, c, nr)
      ..cubicTo(c + nr * 0.78, nr, c + nw * 0.55, 0, c + nw, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..close();

    canvas.drawPath(path, Paint()..color = T.card);
  }

  @override
  bool shouldRepaint(covariant _PintorBarra old) => old.cx != cx;
}
