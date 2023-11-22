import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tcc2023/firebase_options.dart';
import 'package:tcc2023/devices.dart';
import 'package:tcc2023/register.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';


// Ponto de entrada do aplicativo.
void main() async {
  // Logs para depuração.
  
  print('[DEBUG] Iniciando função principal...');

  // Garantindo a inicialização do Flutter para execução de código antes do runApp.
  WidgetsFlutterBinding.ensureInitialized();
  print('[DEBUG] WidgetsFlutterBinding OK! [1/3]');

  // Variável para verificar se todas as inicializações foram bem-sucedidas.
  bool allInitializationsSuccessful = true;

  // Inicializa o Firebase no aplicativo.
  try {
    await initializeFirebase(); 
    print('[DEBUG] Firebase OK! [2/3]');
  } catch (e) {
    allInitializationsSuccessful = false;
    print('[ERROR] Falha na inicialização do Firebase: $e');
  }


  // Se todas as inicializações foram bem-sucedidas, inicia o aplicativo Flutter.
  if (allInitializationsSuccessful) {
    runApp(MyApp());
    print('[DEBUG] Aplicativo OK! [3/3]');
  } else {
    print(
        '[ERROR] Não foi possível iniciar o aplicativo devido a falhas de inicialização anteriores.');
  }
}

// Função para inicializar o Firebase, carregando as configurações padrão da plataforma.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// Widget principal do aplicativo.
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  User? _user; // Usuário atualmente autenticado, se houver.
  bool _isApiOffline = false; // Flag para verificar se a API está offline.

  @override
  void initState() {
    super.initState();
    // Verifica o estado de autenticação ao inicializar.
    _checkAuthentication();
  }

  // Método para verificar a autenticação e a disponibilidade da API.
  _checkAuthentication() async {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      try {
        // Faz uma chamada para verificar a saúde/disponibilidade da API.
        final response = await http.get(Uri.parse('$urlAUX/health_check'));

        // Se a API estiver inativa, ajusta o estado correspondente.
        if (response.statusCode != 200) {
          _setApiOffline();
          print('API inativa.');
        }
      } catch (error) {
        // Captura erros durante a chamada HTTP e ajusta o estado se houver falha.
        _setApiOffline();
        print('API inativa.');
      }

      // Atualiza o estado com o usuário atual, se houver.
      setState(() {
        _user = user;
      });
    });
  }

  // Método para ajustar a flag indicando que a API está offline.
  void _setApiOffline() {
    setState(() {
      _isApiOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Constrói a UI principal do aplicativo, mostrando diferentes telas 
    // com base no estado de autenticação e disponibilidade da API.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: (_user == null || _isApiOffline)
          ? LoginScreen(onApiOffline: _setApiOffline)  // Tela de Log in, caso a API estja inativa.
          : HomeScreen(),                              // Tela principal do app, pós log in efetuado com sucesso.
    );
  }
}
