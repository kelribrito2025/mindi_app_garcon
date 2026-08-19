import 'package:flutter/material.dart';
import 'tema.dart';
import 'api.dart';
import 'sessao.dart';

class TelaEditarPerfil extends StatefulWidget {
  const TelaEditarPerfil({super.key});

  @override
  State<TelaEditarPerfil> createState() => _TelaEditarPerfilState();
}

class _TelaEditarPerfilState extends State<TelaEditarPerfil> {
  late final TextEditingController _nome =
      TextEditingController(text: Sessao.nome);

  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  bool get _nomeValido {
    final n = _nome.text.trim().length;
    return n >= 3 && n <= 10;
  }

  bool get _podeSalvar => _nomeValido && !_salvando;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final nome = _nome.text.trim();

      if (apiConfigurada) {
        await Api.editarPerfil(nome: nome);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
      }
      await Sessao.atualizarGarcom({'name': nome});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dados atualizados'),
        backgroundColor: T.green,
        behavior: SnackBarBehavior.floating,
      ));
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
        _erro = 'Não foi possível salvar. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TelaInterna(
      titulo: 'Meus dados',
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
                  rotulo: 'Nome completo',
                  controller: _nome,
                  dica: 'Como você quer ser chamado (até 10 letras)',
                  maximo: 10,
                  aoMudar: () => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // telefone e restaurante não podem ser editados aqui
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.campo,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.borda),
            ),
            child: Column(
              children: [
                _LinhaFixa(
                    rotulo: 'E-mail',
                    valor: Sessao.email.isEmpty ? '—' : Sessao.email),
                const SizedBox(height: 10),
                _LinhaFixa(
                    rotulo: 'Restaurante',
                    valor: Sessao.empresa.isEmpty ? '—' : Sessao.empresa),
                const SizedBox(height: 10),
                Text(
                  'Para mudar o e-mail ou o restaurante, fale com quem administra o seu cadastro.',
                  style: TextStyle(fontSize: 11.5, color: T.inkSoft, height: 1.4),
                ),
              ],
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                style: TextStyle(fontSize: 12.5, color: T.redDark)),
          ],

          const SizedBox(height: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _podeSalvar ? _salvar : null,
            child: Opacity(
              opacity: _podeSalvar ? 1 : .45,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: kGradRed,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Salvar alterações',
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

class _Campo extends StatelessWidget {
  final String rotulo, dica;
  final TextEditingController controller;
  final TextInputType? teclado;
  final VoidCallback aoMudar;
  final int? maximo;
  const _Campo({
    required this.rotulo,
    required this.dica,
    required this.controller,
    required this.aoMudar,
    this.teclado,
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
          keyboardType: teclado,
          maxLength: maximo,
          onChanged: (_) => aoMudar(),
          style: TextStyle(fontSize: 15, color: T.ink),
          decoration: InputDecoration(
            isDense: true,
            counterText: '', // esconde o "0/10" embaixo do campo
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            filled: true,
            fillColor: T.campo,
            hintText: dica,
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
          ),
        ),
      ],
    );
  }
}

class _LinhaFixa extends StatelessWidget {
  final String rotulo, valor;
  const _LinhaFixa({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(rotulo,
            style: TextStyle(fontSize: 12.5, color: T.inkSoft)),
        Flexible(
          child: Text(valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: T.ink)),
        ),
      ],
    );
  }
}
