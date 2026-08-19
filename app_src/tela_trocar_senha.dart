import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tema.dart';
import 'icones.dart';
import 'api.dart';

class TelaTrocarSenha extends StatefulWidget {
  const TelaTrocarSenha({super.key});

  @override
  State<TelaTrocarSenha> createState() => _TelaTrocarSenhaState();
}

class _TelaTrocarSenhaState extends State<TelaTrocarSenha> {
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirma = TextEditingController();

  // começam visíveis: o garçom confere o que digitou.
  // Se quiser esconder, é só tocar no olhinho.
  bool _verAtual = true, _verNova = true, _verConfirma = true;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirma.dispose();
    super.dispose();
  }

  bool get _tamanhoOk => _nova.text.length >= 6;
  bool get _iguaisOk => _nova.text.isNotEmpty && _nova.text == _confirma.text;
  bool get _podeSalvar =>
      _atual.text.isNotEmpty && _tamanhoOk && _iguaisOk;

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
      _salvando = true;
    });

    try {
      String msg = 'Senha alterada com sucesso';
      if (apiConfigurada) {
        msg = await Api.trocarSenha(_atual.text, _nova.text);
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
      }

      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: T.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } on ApiErro catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível trocar a senha. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TelaInterna(
      titulo: 'Trocar minha senha',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sombraCard(),
            ),
            child: Column(
              children: [
                _Campo(
                  rotulo: 'Senha atual',
                  controller: _atual,
                  escondido: !_verAtual,
                  
                  aoVerAlternar: () => setState(() => _verAtual = !_verAtual),
                  aoMudar: () => setState(() {}),
                ),
                const SizedBox(height: 14),
                _Campo(
                  rotulo: 'Nova senha',
                  controller: _nova,
                  escondido: !_verNova,
                  
                  aoVerAlternar: () => setState(() => _verNova = !_verNova),
                  aoMudar: () => setState(() {}),
                ),
                const SizedBox(height: 14),
                _Campo(
                  rotulo: 'Confirmar nova senha',
                  controller: _confirma,
                  escondido: !_verConfirma,
                  
                  aoVerAlternar: () =>
                      setState(() => _verConfirma = !_verConfirma),
                  aoMudar: () => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- regras ----------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.campo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.borda),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A nova senha precisa ter:',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: T.ink)),
                const SizedBox(height: 9),
                _Regra(texto: 'Pelo menos 6 caracteres', ok: _tamanhoOk),
                const SizedBox(height: 6),
                _Regra(texto: 'As duas senhas devem ser iguais', ok: _iguaisOk),
              ],
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                style: TextStyle(fontSize: 12.5, color: T.redDark)),
          ],

          const SizedBox(height: 20),

          // ---------- botão salvar ----------
          GestureDetector(
            onTap: _podeSalvar && !_salvando ? _salvar : null,
            child: Opacity(
              opacity: _podeSalvar && !_salvando ? 1 : .45,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: kGradRed,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _podeSalvar
                      ? [
                          BoxShadow(
                            color: T.redDark.withOpacity(.3),
                            blurRadius: 14,
                            offset: const Offset(0, 7),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Salvar nova senha',
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('Cancelar',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: T.inkSoft)),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- campo de senha ---------------- */
class _Campo extends StatelessWidget {
  final String rotulo;
  final TextEditingController controller;
  final bool escondido;
  final VoidCallback aoVerAlternar;
  final VoidCallback aoMudar;
  final int? maximo;

  const _Campo({
    required this.rotulo,
    required this.controller,
    required this.escondido,
    required this.aoVerAlternar,
    required this.aoMudar,
    this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: T.rotulo)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: escondido,
          maxLength: maximo,
          keyboardType: TextInputType.text,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          onChanged: (_) => aoMudar(),
          style: TextStyle(fontSize: 15, color: T.ink),
          decoration: InputDecoration(
            isDense: true,
            counterText: '', // esconde o "0/8" embaixo do campo
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: T.campo,
            
            hintStyle: TextStyle(color: T.fraco),
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
            suffixIcon: IconButton(
              onPressed: aoVerAlternar,
              icon: Icon(
                escondido
                    ? Ico.olhoFechado
                    : Ico.olho,
                size: 20,
                color: T.inkSoft,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------------- linha de regra ---------------- */
class _Regra extends StatelessWidget {
  final String texto;
  final bool ok;
  const _Regra({required this.texto, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ok ? Ico.checkCirculo : Ico.bolaVazia,
          size: 16,
          color: ok ? T.green : T.fraco,
        ),
        const SizedBox(width: 8),
        Text(texto,
            style: TextStyle(
                fontSize: 12.5,
                color: ok ? T.ink : T.inkSoft,
                fontWeight: ok ? FontWeight.w600 : FontWeight.w500)),
      ],
    );
  }
}
