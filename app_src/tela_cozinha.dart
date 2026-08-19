import 'package:flutter/material.dart';
import 'tema.dart';
import 'icones.dart';

/* ================================================================== *
 *  ABA COZINHA — o que já está pronto para levar à mesa
 *
 *  Reservada: a documentação da API ainda não define como listar os
 *  itens por situação de preparo. Quando chegar, é só preencher aqui
 *  — o resto do app não muda.
 * ================================================================== */
class TelaCozinha extends StatelessWidget {
  const TelaCozinha({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
          bottom: 130 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeaderVermelho(child: BarraBoasVindas()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSide),
            child: Column(
              children: [
                const SizedBox(height: 50),
                Icon(Ico.cozinha, size: 42, color: T.fraco),
                const SizedBox(height: 14),
                Text('Em construção',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: T.ink)),
                const SizedBox(height: 6),
                Text(
                  'Aqui vão aparecer os pratos que a cozinha já terminou,\n'
                  'para você levar à mesa certa.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13.5, height: 1.5, color: T.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
