import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tcc2023/devices.dart';
import 'package:http/http.dart' as http; // Para fazer solicitações HTTP
import 'callbacks.dart';
import 'constants.dart';
import 'package:google_fonts/google_fonts.dart';

// ignore_for_file: deprecated_member_use

// Definindo duas constantes para cores que serão usadas no tema do app.
const primaryColor = Color(0xFF1976D2);
const secondaryColor = Color(0xFF80DEEA);

// 'RegisterScreen' é o widget que apresenta a tela de registro.
class RegisterScreen extends StatefulWidget {
  final SetApiOfflineCallback
      onApiOffline; // Callback que é chamado quando a API está offline.

  // Construtor requerindo o callback 'onApiOffline'.
  // Boa prática passar uma "Key" para o construtor de widgets que são expostos
  // publicamente (que podem ser usados em outras widgets em diferentes partes do app),
  // isso permite controlar a identidade única de cada widget.
  const RegisterScreen({required this.onApiOffline, Key? key})
      : super(key: key);

  @override
  _RegisterScreenState createState() =>
      _RegisterScreenState(); // Criando o estado relacionado.
}

// Classe que mantém o estado do widget 'RegisterScreen'.
class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para os campos de texto, capturando o e-mail e a senha.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Método assíncrono para registrar um novo usuário.
  Future<void> _register() async {
    try {
      // Validação de entrada básica
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      if (email.isEmpty || !email.contains('@')) {
        _showErrorSnackBar('Por favor, insira um e-mail válido.');
        return;
      }
      if (password.length < 6) {
        _showErrorSnackBar('A senha deve ter pelo menos 6 caracteres.');
        return;
      }

      // Registro com Firebase
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Verificação da disponibilidade da API
      final response = await http.get(Uri.parse('$urlAUX/health_check'));

      // Se a API não estiver acessível, executa o callback 'onApiOffline', faz logout no Firebase e lança uma exceção.
      // Senão, printa que foi registrado com sucesso, e envia o usuario para a homescreen
      if (response.statusCode != 200) {
        widget.onApiOffline();
        await FirebaseAuth.instance.signOut();
        throw Exception("API está desligada ou inacessível");
      } else {
        print('Registro efetuado com sucesso!');
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) {
        // Aqui, a mensagem de erro pode ser personalizada com base no erro específico recebido durante o registro.
        _showErrorSnackBar('Erro ao fazer registro: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Método 'build' para construir a interface da tela de registro.
  @override
  Widget build(BuildContext context) {
    // 'Scaffold' é um widget que implementa a estrutura básica do material design visual.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'), // Título da barra superior
        backgroundColor: primaryColor, // Cor de fundo da barra superior
      ),
      // O corpo do 'Scaffold' é um 'Padding' com uma 'Column', que contém os campos de texto e o botão de registro.
      body: Padding(
        padding: const EdgeInsets.all(
            16.0), // Adiciona um espaçamento interno de todos os lados do widget filho.
        child: Column(
          mainAxisAlignment: MainAxisAlignment
              .center, // Centraliza os widgets no eixo principal (vertical).
          crossAxisAlignment: CrossAxisAlignment
              .stretch, // Estica os widgets no eixo cruzado (horizontal).
          children: <Widget>[
            // ... [Widgets para entrada de e-mail e senha, botão de registro, etc., seguem aqui]
            Center(
              child: Transform.translate(
                offset: const Offset(0.0, -80.0),
                child: Text(
                  textAlign: TextAlign.center,
                  'Hub\nSystem\nControl',
                  style: GoogleFonts.orbitron(
                    fontSize: 70.0,
                    shadows: [
                      const Shadow(
                        blurRadius: 5.0,
                        color: Colors.black,
                        offset: Offset(2.0, 4.0),
                      ),
                    ],
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email, color: secondaryColor),
                labelText: 'Email',
                labelStyle: TextStyle(color: secondaryColor),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock, color: secondaryColor),
                labelText: 'Senha',
                labelStyle: TextStyle(color: secondaryColor),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: primaryColor,
                onPrimary: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                elevation: 5.0,
                padding: const EdgeInsets.all(12.0),
              ),
              onPressed: _register,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}

// 'LoginScreen' é semelhante ao 'RegisterScreen', mas para login. Tem uma estrutura similar.
class LoginScreen extends StatefulWidget {
  final SetApiOfflineCallback onApiOffline;

  const LoginScreen({required this.onApiOffline, Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Método assíncrono para logar um usuário existente.
  Future<void> _login() async {
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();

      // Tente fazer login com o Firebase.
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final response = await http.get(Uri.parse('$urlAUX/health_check'));

      // Se a API não estiver acessível, faça logout e informe o usuário.
      if (response.statusCode != 200) {
        await FirebaseAuth.instance
            .signOut(); // Garantir que o usuário seja deslogado.
        widget.onApiOffline(); // Chame o método que lida com a API offline.

        throw Exception("API está desligada ou inacessível");
      } else {
        // Se tudo estiver funcionando corretamente, prossiga para a próxima tela.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      }
    } catch (e) {
      // Se houver um problema, exiba uma mensagem para o usuário.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Erro ao fazer login. Verifique suas credenciais ou a disponibilidade da API.'),
          ),
        );
      }
    }
  }

  // Método 'build' para construir a interface da tela de login.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecte-se'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ... [A estrutura aqui é semelhante à tela de registro, mas com funcionalidades de login]
            Center(
              child: Transform.translate(
                offset: const Offset(0.0, -80.0),
                child: Text(
                  textAlign: TextAlign.center,
                  'Hub\nSystem\nControl',
                  style: GoogleFonts.orbitron(
                    fontSize: 70.0,
                    shadows: [
                      const Shadow(
                        blurRadius: 5.0,
                        color: Colors.black,
                        offset: Offset(2.0, 4.0),
                      ),
                    ],
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email, color: secondaryColor),
                labelText: 'Email',
                labelStyle: TextStyle(color: secondaryColor),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock, color: secondaryColor),
                labelText: 'Senha',
                labelStyle: TextStyle(color: secondaryColor),
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: primaryColor,
                onPrimary: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                elevation: 5.0,
                padding: const EdgeInsets.all(12.0),
              ),
              onPressed: _login,
              child: const Text('Entrar'),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: secondaryColor,
                onPrimary: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                elevation: 5.0,
                padding: const EdgeInsets.all(12.0),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          RegisterScreen(onApiOffline: widget.onApiOffline)),
                );
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
