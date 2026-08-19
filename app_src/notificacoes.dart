import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alerta.dart';
import 'api.dart';
import 'sessao.dart';
import 'estado.dart';

/* ================================================================== *
 *  NOTIFICAÇÕES (Firebase Cloud Messaging)
 *
 *  Como funciona:
 *   - ligarFirebase()  -> roda 1x quando o app abre. Também cria o
 *                         "canal de aviso" do Android (ver abaixo).
 *   - registrar()      -> roda depois do login, pede permissão e
 *                         manda o token do celular para a API
 *
 *  Sobre o CANAL:
 *   No Android, cada aviso pertence a um "canal". O canal é quem manda
 *   no som, na vibração e em aparecer por cima da tela. O canal padrão
 *   do sistema é fraco: muitas vezes o aviso chega mudo e sem vibrar.
 *   Por isso o app cria o canal "Avisos do salão" com prioridade máxima
 *   e vibração forte, e usa ele em todos os avisos.
 *
 *  Com o app FECHADO ou em segundo plano quem desenha o aviso é o
 *  próprio Android (usando esse canal). Com o app ABERTO o Android não
 *  desenha nada sozinho, então o app desenha o aviso ele mesmo aqui.
 * ================================================================== */

/// vibração do aviso: 3 pulsos longos
final _padraoVibra = Int64List.fromList([0, 600, 250, 600, 250, 800]);

/// o canal de aviso novo
final _canalAvisos = AndroidNotificationChannel(
  'garcom_mindi',
  'Avisos do salão',
  description: 'Aviso pronto e conta solicitada',
  importance: Importance.max,
  enableVibration: true,
  vibrationPattern: _padraoVibra,
  playSound: true,
);

final _avisosLocais = FlutterLocalNotificationsPlugin();

/// Precisa ser função de topo e ter o @pragma, senão o Android
/// não consegue acordar o app com a mensagem.
@pragma('vm:entry-point')
Future<void> _mensagemEmSegundoPlano(RemoteMessage mensagem) async {
  // O sistema já exibe a notificação usando o canal "Avisos do salão".
  // Aqui só anotamos o número do aviso: quando o garçom abrir o
  // app, a tela Início procura por ele mesmo que não venha na lista.
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}
}

int? _numeroDaMesa(dynamic bruto) =>
    bruto is int ? bruto : int.tryParse('${bruto ?? ''}');

/// Lê o orderId que veio na notificação e avisa a tela Início.
void _guardarMesa(RemoteMessage mensagem) {
  _abrirMesaNaTela(mensagem.data['tableId']);
}

void _abrirMesaNaTela(dynamic bruto) {
  final id = bruto is int ? bruto : int.tryParse('${bruto ?? ''}');
  if (id == null) return;
  abaSelecionada.value = 0;
  mesaDaNotificacao.value = id;
}

/// o garçom tocou no aviso que o próprio app desenhou
@pragma('vm:entry-point')
void _aoTocarAvisoLocal(NotificationResponse resposta) {
  _abrirMesaNaTela(resposta.payload);
}

/// o app está aberto na tela, não minimizado nem fechado
bool get _appNaFrente =>
    WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

class Notificacoes {
  static bool _pronto = false;

  /// último aviso já mostrado (evita aviso repetido)
  static int? _ultimoAvisado;
  static DateTime? _horaDoUltimoAviso;
  static String? _ultimoToken;
  static bool _ouvindoRefresh = false;

  static bool get pronto => _pronto;

  /// Inicia o Firebase. Chamado uma única vez, antes do runApp.
  static Future<void> ligarFirebase() async {
    if (_pronto) return;
    try {
      await Firebase.initializeApp();
      await _prepararAvisos();

      FirebaseMessaging.onBackgroundMessage(_mensagemEmSegundoPlano);

      // app estava FECHADO e o garçom tocou na notificação
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) _guardarMesa(inicial);

      // app estava em SEGUNDO PLANO e o garçom tocou na notificação
      FirebaseMessaging.onMessageOpenedApp.listen(_guardarMesa);

      // app ABERTO na tela: o Android não mostra nada sozinho, então o
      // app desenha o aviso (com som e vibração) e atualiza a lista
      FirebaseMessaging.onMessage.listen((mensagem) async {
        // Só desenha o aviso se o app estiver mesmo na frente do
        // garçom. Fora isso quem desenha é o Android, e desenhar
        // aqui também faria a notificação aparecer duas vezes.
        if (_appNaFrente) _mostrarAviso(mensagem);

        avisoDeNovidade.value = avisoDeNovidade.value + 1;
      });

      _pronto = true;
    } catch (_) {
      // sem Firebase configurado: o app continua funcionando normal
      _pronto = false;
    }
  }

  /// cria o canal "Avisos do salão" e prepara o aviso desenhado pelo app
  static Future<void> _prepararAvisos() async {
    try {
      await _avisosLocais.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _aoTocarAvisoLocal,
      );

      final android = _avisosLocais.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_canalAvisos);

      // app estava FECHADO e o garçom tocou no aviso do app
      final abriuPorAviso =
          await _avisosLocais.getNotificationAppLaunchDetails();
      final resposta = abriuPorAviso?.notificationResponse;
      if (abriuPorAviso?.didNotificationLaunchApp == true && resposta != null) {
        _abrirMesaNaTela(resposta.payload);
      }
    } catch (_) {
      // celular sem suporte: segue sem o aviso desenhado pelo app
    }
  }

  /// desenha o aviso na barra do Android (usado com o app aberto)
  static Future<void> _mostrarAviso(RemoteMessage mensagem) async {
    try {
      final aviso = mensagem.notification;
      final dados = mensagem.data;

      // mesma mesa avisada há pouco: não repete
      final numero = _numeroDaMesa(dados['tableId']);
      final agora = DateTime.now();
      if (numero != null &&
          numero == _ultimoAvisado &&
          _horaDoUltimoAviso != null &&
          agora.difference(_horaDoUltimoAviso!).inSeconds < 60) {
        return;
      }
      _ultimoAvisado = numero;
      _horaDoUltimoAviso = agora;

      var titulo = aviso?.title ?? '';
      if (titulo.isEmpty) titulo = '${dados['title'] ?? ''}';
      if (titulo.isEmpty) titulo = 'Aviso do salão';

      var texto = aviso?.body ?? '';
      if (texto.isEmpty) texto = '${dados['body'] ?? ''}';
      if (texto.isEmpty) texto = 'Toque para abrir a mesa.';

      await _avisosLocais.show(
        // id fixo: um aviso novo substitui o anterior
        1001,
        titulo,
        texto,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _canalAvisos.id,
            _canalAvisos.name,
            channelDescription: _canalAvisos.description,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: _padraoVibra,
            playSound: true,
            ticker: 'Salão',
            visibility: NotificationVisibility.public,
          ),
        ),
        payload: '${dados['tableId'] ?? ''}',
      );

      // o aviso já vibrou: a tela não precisa vibrar de novo
      marcarAlertaFeito();
    } catch (_) {
      // se não deu para desenhar o aviso, a tela ainda vibra sozinha
      alertarAvisoNovo();
    }
  }

  /// Pede a permissão de notificação e envia o token para a API.
  /// Chamado depois do login (e na abertura, se já estiver logado).
  static Future<void> registrar() async {
    if (!_pronto || !Sessao.logado) return;
    try {
      final fm = FirebaseMessaging.instance;

      await fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await fm.setAutoInitEnabled(true);

      // no Android 13+ a permissão de aviso é pedida também por aqui
      try {
        await _avisosLocais
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}

      // com o app aberto quem desenha o aviso é o próprio app
      await fm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _enviarToken(await fm.getToken());

      if (!_ouvindoRefresh) {
        _ouvindoRefresh = true;
        fm.onTokenRefresh.listen(_enviarToken);
      }
    } catch (_) {
      // permissão negada ou sem internet: tenta de novo no próximo login
    }
  }

  static Future<void> _enviarToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (token == _ultimoToken) return;
    if (!apiConfigurada || !Sessao.logado) return;
    try {
      await Api.registrarPushToken(token);
      _ultimoToken = token;
    } catch (_) {
      // se falhar, o token é reenviado no próximo login
    }
  }

  /// Chamado ao sair da conta, para o próximo login mandar o token de novo.
  static Future<void> esquecer() async {
    _ultimoToken = null;
    try {
      await _avisosLocais.cancelAll();
    } catch (_) {}
    if (!_pronto) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}
