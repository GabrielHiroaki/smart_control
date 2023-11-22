import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'dart:math';
import 'package:tcc2023/register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

// ignore_for_file: deprecated_member_use

// Enumeração representando os tipos de dispositivos suportados pelo app.
enum DeviceType {
  arCondicionado,
  tv,
  lampada,
  tomada,
}

// Classe que define as características e comportamentos de um dispositivo.
class Device {
  final String firestoreId; // Identificador único para referências no Firestore
  final String name; // Nome amigável para o dispositivo, utilizado na UI
  final DeviceType
      type; // Tipo do dispositivo, conforme definido pela enumeração DeviceType.
  bool isOn; // Estado atual do dispositivo (ligado/desligado)
  int temperature; // Temperatura configurada para o dispositivo (ar)
  int scheduledHours; // Horas programadas para o agendamento (ar)
  int scheduledMinutes; // Minutos programados para o agendamento (ar)
  int scheduledSeconds; // Segundos programados para o agendamento (ar)
  int currentChannel; // Canal atual no dispositivo (tv)
  int currentVolume; // Volume atual no dispositivo (tv)
  bool isMuted; // Estado atual de mudo no dispositivo (tv)

  // Construtor para criar uma instância do dispositivo com valores opcionais e padrões.
  Device({
    this.firestoreId = '',
    required this.name,
    required this.type,
    this.isOn = false,
    this.temperature = 25,
    this.scheduledHours = 0,
    this.scheduledMinutes = 0,
    this.scheduledSeconds = 0,
    this.currentChannel = 1,
    this.currentVolume = 50,
    this.isMuted = false,
  });

  // Método para criar uma cópia de uma instância de Device, permitindo a alteração de alguns atributos.
  Device copyWith({
    String? firestoreId,
    String? name,
    DeviceType? type,
    bool? isOn,
    int? temperature,
    int? scheduledHours,
    int? scheduledMinutes,
    int? scheduledSeconds,
    int? currentChannel,
    int? currentVolume,
    bool? isMuted,
  }) {
    return Device(
      firestoreId: firestoreId ??
          this.firestoreId, // Se nenhum novo valor for fornecido, mantém o atual.
      name: name ?? this.name, //...
      type: type ?? this.type, //...
      isOn: isOn ?? this.isOn, //...
      temperature: temperature ?? this.temperature, //...
      scheduledHours: scheduledHours ?? this.scheduledHours, //...
      scheduledMinutes: scheduledMinutes ?? this.scheduledMinutes, //...
      scheduledSeconds: scheduledSeconds ?? this.scheduledSeconds, //...
      currentChannel: currentChannel ?? this.currentChannel, //...
      currentVolume: currentVolume ?? this.currentVolume, //...
      isMuted: isMuted ?? this.isMuted, //...
    );
  }

  // Construtor de fábrica para criar uma instância de Device a partir de um Map.
  // Útil para integração com fontes de dados que utilizam estruturas de Map, como bancos de dados.
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      // Atribuição direta de valores do Map para os atributos da nova instância de Device.
      firestoreId: map['firestoreId'],
      name: map['name'],
      type: DeviceType.values[map['type']],
      isOn: map['isOn'],
      temperature: map['temperature'],
      scheduledHours: map['scheduledHours'],
      scheduledMinutes: map['scheduledMinutes'],
      scheduledSeconds: map['scheduledSeconds'],
      currentChannel: map['currentChannel'],
      currentVolume: map['currentVolume'],
      isMuted: map['isMuted'],
    );
  }

  // Método para converter uma instância de Device em um Map.
  // Útil para enviar dados para fontes que aceitam estruturas de Map, como bancos de dados.
  Map<String, dynamic> toMap() {
    return {
      // Criação de um Map, associando as chaves (strings) aos respectivos valores dos atributos do Device.
      'firestoreId': firestoreId,
      'name': name,
      'type': type.index,
      'isOn': isOn,
      'temperature': temperature,
      'scheduledHours': scheduledHours,
      'scheduledMinutes': scheduledMinutes,
      'scheduledSeconds': scheduledSeconds,
      'currentChannel': currentChannel,
      'currentVolume': currentVolume,
      'isMuted': isMuted,
    };
  }
}

class DeviceEvent {
  final bool isOn; // O estado atual do dispositivo.
  final bool isSuccess; // Se o comando foi bem-sucedido ou não.
  final String? errorMessage; // Mensagem de erro, se houver.

  DeviceEvent({required this.isOn, this.isSuccess = true, this.errorMessage});
}

// 'HomeScreen' é a classe principal que representa a tela inicial do app.
// Ela é um StatefulWidget, o que significa que ela pode manter um estado que pode mudar durante a vida útil do widget.
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

// '_HomeScreenState' é a classe que contém a lógica e a interface do usuário para a tela 'HomeScreen'.
// Ela gerencia o estado da tela e se comunica com serviços externos, como a API e o Firestore.
class _HomeScreenState extends State<HomeScreen> {
  int deviceIndex =
      0; // Índice usado para acompanhar qual dispositivo está sendo manipulado.
  String selectedOption =
      "Devices"; // Controla a visualização selecionada pelo usuário (Dispositivos ou Sensores).
  List<Device> devices =
      []; // Lista que armazena os dispositivos obtidos do Firestore.
  StreamSubscription?
      devicesSubscription; // Inscrição para ouvir as mudanças na coleção de dispositivos no Firestore.
  double? temperature; // Temperatura atual obtida do sensor.
  double? humidity; // Umidade atual obtida do sensor.

  @override
  void initState() {
    super.initState();
    setupDevicesListener(); // Configurar o ouvinte para mudanças na coleção de dispositivos do Firestore.
    if (selectedOption == "Sensores") {
      _fetchSensorData(); // Se a opção selecionada for 'Sensores', obtenha os dados do sensor.
    }
  }

  // função para receber os dados da leitura do sensor
  // mediante a api que efetua a requisição e retorna para o app.
  Future<void> _fetchSensorData() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final apiURL = Uri.parse('$urlAUX/sensor?userId=$userId');

    try {
      final response = await http.get(apiURL);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Definindo os valores no estado e imprimindo-os
        setState(() {
          temperature = data['temperature'].toDouble();
          humidity = data['humidity'].toDouble();
        });

        print("Temperature set to: $temperature");
        print("Humidity set to: $humidity");
      } else {
        print(
            "[DEBUG] Erro ao buscar dados do sensor da API: Status code ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao visualizar dados do sensor.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("[DEBUG] Exceção ao buscar dados do sensor da API: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exceção ao buscar dados do sensor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // função responsável por remover o dispositivo do firebase (firestore)
  // utiliza-se a api para enviar a requisição para remoção.
  Future<void> removeDeviceFromFirestore(Device device, int index) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId != null && (device.firestoreId.isNotEmpty)) {
      try {
        print(
            'UserId: $userId, FirestoreId: ${device.firestoreId}, Index: $index');

        final encodedDeviceName = Uri.encodeComponent(device.firestoreId);

        final apiURL = '$urlAUX/devices/$userId/$encodedDeviceName';

        final response = await http.delete(Uri.parse(apiURL));

        if (response.statusCode != 200) {
          print(
              '[DEBUG] Erro ao remover dispositivo, verificar disponibilidade da API!: ${response.body}');
        } else {
          print('[DEBUG] Dispositivo removido com o ID: ${device.firestoreId}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dipositivo removido com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '[DEBUG] Erro ao tentar remover dispositivo: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('[DEBUG] UserId é nulo ou firestoreId está vazio.');
    }
  }

  // Esta função configura um ouvinte em tempo real para a coleção 'devices' no Firestore.
  // Qualquer adição, remoção ou modificação na coleção acionará o código aqui, atualizando a interface do usuário.
  void setupDevicesListener() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId != null) {
      devicesSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('devices')
          .snapshots()
          .listen((snapshot) {
        final devicesData = snapshot.docs.map((doc) {
          final data = doc.data();

          final type = DeviceType.values[data['type']];

          switch (type) {
            case DeviceType.arCondicionado:
              return Device(
                firestoreId: doc.id,
                name: data['name'] ?? "",
                type: type,
                isOn: data['isOn'] ?? false,
                temperature: data['temperature'] ?? 25,
                scheduledHours: data['scheduledHours'] ?? 0,
                scheduledMinutes: data['scheduledMinutes'] ?? 0,
                scheduledSeconds: data['scheduledSeconds'] ?? 0,
              );
            case DeviceType.tv:
              return Device(
                firestoreId: doc.id,
                name: data['name'] ?? "",
                type: type,
                isOn: data['isOn'] ?? false,
                currentChannel: data['currentChannel'] ?? 1,
                currentVolume: data['currentVolume'] ?? 50,
                isMuted: data['isMuted'] ?? false,
              );
            case DeviceType.tomada:
            case DeviceType.lampada:
              return Device(
                firestoreId: doc.id,
                name: data['name'] ?? "",
                type: type,
                isOn: data['isOn'] ?? false,
              );
            default:
              throw Exception("[DEBUG] Tipo de dispositivo desconhecido.");
          }
        }).toList();

        setState(() {
          devices = devicesData;
        });
      });
    }
  }

  @override
  void dispose() {
    devicesSubscription
        ?.cancel(); // Cancela a inscrição quando o widget for descartado para evitar vazamentos de memória.
    super.dispose();
  }

  // função responsável por adicionar o dispositivo no firestore,
  // passando pela a API para efetuar a requisição de POST.
  Future<void> addDeviceToFirestore(Device device) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    if (userId != null) {
      Map<String, dynamic> deviceData = {
        'name': device.name,
        'type': device.type.index,
        'isOn': device.isOn,
      };

      // Preencher os dados do dispositivo de acordo com o tipo
      switch (device.type) {
        case DeviceType.arCondicionado:
          deviceData.addAll({
            'temperature': device.temperature,
            'scheduledHours': device.scheduledHours,
            'scheduledMinutes': device.scheduledMinutes,
            'scheduledSeconds': device.scheduledSeconds,
          });
          break;
        case DeviceType.tv:
          deviceData.addAll({
            'channel': device.currentChannel,
            'volume': device.currentVolume,
            'isMuted': device.isMuted,
          });
          break;
        case DeviceType.tomada:
        case DeviceType.lampada:
          // No extra data
          break;
        default:
          throw Exception("[DEBUG] Tipo de dispositivo desconhecido.");
      }

      final response = await http.post(
        Uri.parse('$urlAUX/devices/$userId'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(deviceData),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        print('[DEBUG] Dispositivo adicionado com o ID: ${responseData["id"]}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dispositivo adicionado com sucesso!.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('[DEBUG] Erro ao adicionar o dispositivo: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao adicionar dispositivo!.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // parte visual do aplicativo, onde vamos poder adicionar
  // os dispositivos, remover, alterar, etc..
  void addDevice(Device device) {
    if (!devices.contains(device)) {
      addDeviceToFirestore(device);

      setState(() {
        devices.add(device);
      });
    }
  }

  void removeDevice(int index) {
    if (index >= 0 && index < devices.length) {
      final device = devices[index];
      removeDeviceFromFirestore(device, index);
    }
  }

  void updateDevice(Device device) {
    setState(() {
      // Atualize o estado do dispositivo com o novo dispositivo
      devices[deviceIndex] = device;
    });
  }

  void showDeviceDetails(int deviceIndex) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true, // Isso permite fechar a folha modal ao tocar fora
      builder: (BuildContext context) {
        return DeviceControlDialog(
          key: ValueKey(devices[deviceIndex]
              .firestoreId), // usando 'firestoreId' como a propriedade única
          device: devices[deviceIndex],
          updateDevice: (updatedDevice) {
            updateDeviceWithIndex(updatedDevice, deviceIndex);
          },
        );
      },
    );
  }

  void updateDeviceWithIndex(Device updatedDevice, int deviceIndex) {
    setState(() {
      devices[deviceIndex] =
          updatedDevice; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Seja bem-vindo...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            shadows: [
              Shadow(
                blurRadius: 3.0,
                color: Colors.black,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          // Botão e lista suspensa
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'logout') {
                _deslogarUsuario(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Sair'),
              ),
            ],
          ),
        ],
      ),
      body: selectedOption == "Devices"
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Padding(padding: EdgeInsets.all(15)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AddDeviceDialog(onAdd: addDevice);
                          },
                        );
                      },
                      icon: const Icon(Icons.add, size: 25),
                      label: const Text('Adicionar Dispositivo'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.greenAccent[700],
                        onPrimary: Colors.white,
                        elevation: 5,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 15),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return RemoveDeviceDialog(
                              devices: devices,
                              onRemove: removeDevice,
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.delete, size: 25),
                      label: const Text('Remover Dispositivo'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.redAccent[700],
                        onPrimary: Colors.white,
                        elevation: 5,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 45),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      print(
                          "[DEBUG] Dispositivo: ${device.name}, Ligado?: ${device.isOn}");
                      Color iconColor =
                          device.isOn ? Colors.green : Colors.grey;

                      return GestureDetector(
                        onTap: () {
                          showDeviceDetails(index);
                        },
                        child: Card(
                          elevation: 15,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: Text(
                                  device.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(2.0, 2.0),
                                        blurRadius: 3.0,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (device.type == DeviceType.tv)
                                Icon(Icons.tv, size: 80, color: iconColor)
                              else if (device.type == DeviceType.arCondicionado)
                                Icon(Icons.ac_unit, size: 80, color: iconColor)
                              else if (device.type == DeviceType.lampada)
                                Icon(Icons.lightbulb_outline,
                                    size: 80, color: iconColor)
                              else if (device.type == DeviceType.tomada)
                                Icon(Icons.power, size: 80, color: iconColor)
                              else
                                const Text('Outro Tipo de Dispositivo'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            )
          : SensorsScreen(
              temperature: temperature,
              humidity: humidity,
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Dispositivos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grain),
            label: 'Sensores',
          ),
        ],
        selectedItemColor: Colors.blue,
        currentIndex: selectedOption == "Devices" ? 0 : 1,
        onTap: (index) {
          if (index == 1) {
            _fetchSensorData();
          }
          setState(() {
            selectedOption = index == 0 ? "Devices" : "Sensores";
          });
        },
      ),
    );
  }

  // Método para deslogar do Firebase
  void _deslogarUsuario(BuildContext context) async {
    try {
      // Desloga do Firebase
      await FirebaseAuth.instance.signOut();

      // Navega de volta para a tela de login após o logout
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            // Aqui, você está criando uma nova instância de LoginScreen.
            // O construtor de LoginScreen espera um callback 'onApiOffline'.
            // Você deve fornecer um método apropriado do escopo atual que corresponda à assinatura do callback.
            builder: (context) => LoginScreen(onApiOffline: () {
              // Este código será executado quando a 'LoginScreen' determinar que a API está offline.
            }),
          ),
        );
      }
    } catch (error) {
      // erros
    }
  }
}

class SensorsScreen extends StatelessWidget {
  final double? temperature;
  final double? humidity;

  // Adicionando 'const' ao construtor e um parâmetro 'key'.
  const SensorsScreen({
    Key? key,
    required this.temperature,
    required this.humidity,
  }) : super(key: key); // Passando key para a classe base.

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(23.0),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Card(
            child: ListTile(
              leading: const Icon(Icons.thermostat_outlined, size: 45),
              iconColor: const Color.fromARGB(255, 255, 0, 0),
              title: const Text('Temperatura'),
              // Utilizando o operador de string para evitar a representação de 'null' na string.
              subtitle: Text('${temperature ?? "N/A"}°C'),
            ),
          ),
          const SizedBox(height: 5),
          Card(
            child: ListTile(
              leading: const Icon(Icons.water_drop_outlined, size: 45),
              iconColor: const Color.fromARGB(255, 4, 0, 255),
              title: const Text('Umidade'),
              // Mesma manipulação segura para a umidade, prevenindo 'null' na UI.
              subtitle: Text('${humidity ?? "N/A"}%'),
            ),
          ),
        ],
      ),
    );
  }
}

// Daqui pra frente, teremos a parte visual de quando selecionamos
// os dispositivos para efetuar suas funcionalidades (ligar, desligar, programação...)
// tanto a parte gráfica, tanto a parte lógica...
// ou seja, teremos a parte da integração da API com o Aplicativo..
class AddDeviceDialog extends StatefulWidget {
  final Function(Device) onAdd;
  const AddDeviceDialog({required this.onAdd, Key? key}) : super(key: key);

  @override
  _AddDeviceDialogState createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final TextEditingController deviceNameController = TextEditingController();
  DeviceType selectedDeviceType = DeviceType.arCondicionado;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: const Text(
        'Adicionar',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<DeviceType>(
            value: selectedDeviceType,
            onChanged: (value) {
              setState(() {
                selectedDeviceType = value!;
              });
            },
            items: DeviceType.values.map((type) {
              return DropdownMenuItem<DeviceType>(
                value: type,
                child: Text(type.toString().split('.').last),
              );
            }).toList(),
          ),
          TextField(
            controller: deviceNameController,
            decoration: const InputDecoration(labelText: 'Insira um nome'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final deviceName = deviceNameController.text;
              if (deviceName.isNotEmpty) {
                final device = Device(
                  name: deviceName,
                  type: selectedDeviceType,
                );
                widget.onAdd(device);
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.greenAccent[700],
              onPrimary: Colors.white,
              elevation: 5,
            ),
            // 'child' no final ajuda na legibilidade e consistência do código.
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class RemoveDeviceDialog extends StatefulWidget {
  final List<Device> devices;
  final Function(int) onRemove;

  // Agora o construtor é const e tem um parâmetro 'key'.
  const RemoveDeviceDialog({
    Key? key,
    required this.devices,
    required this.onRemove,
  }) : super(key: key); // Passe 'key' para a classe base.

  @override
  _RemoveDeviceDialogState createState() => _RemoveDeviceDialogState();
}

class _RemoveDeviceDialogState extends State<RemoveDeviceDialog> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: const Text(
        'Remover',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<int>(
            hint: const Text("Selecione o dispositivo"),
            value: selectedIndex,
            onChanged: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
            items: List.generate(widget.devices.length, (index) {
              return DropdownMenuItem<int>(
                value: index,
                child: Text(widget.devices[index].name),
              );
            }),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (selectedIndex != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmação'),
                    content: const Text(
                        'Gostaria de deletar o dispositivo selecionado?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.onRemove(selectedIndex!);
                          Navigator.of(context)
                              .pop(); // fecha o diálogo de confirmação
                          Navigator.of(context)
                              .pop(); // fecha o diálogo de remoção
                        },
                        child: const Text('Deletar'),
                      ),
                    ],
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              elevation: 5,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Classe singleton que gerencia os eventos do dispositivo.
// Classe singleton é garantir que uma classe tenha apenas uma instância (ou seja, um único objeto da classe)
// durante a execução do programa e fornecer um ponto de acesso global a essa instância.
class DeviceEventService {
  // Criando uma instância singleton da classe.
  static final DeviceEventService _instance = DeviceEventService._internal();
  factory DeviceEventService() {
    return _instance;
  }
  DeviceEventService._internal();

  // Controlador de stream para gerenciar os eventos do dispositivo.
  final StreamController<DeviceEvent> deviceEventController =
      StreamController<DeviceEvent>.broadcast();
}

class DeviceControlDialog extends StatefulWidget {
  final Device device;
  final Function(Device) updateDevice;

  const DeviceControlDialog({
    Key? key,
    required this.device,
    required this.updateDevice,
  }) : super(key: key);

  @override
  _DeviceControlDialogState createState() => _DeviceControlDialogState();
}

class _DeviceControlDialogState extends State<DeviceControlDialog> {
  final _shouldRestoreState = true;
  bool _isOn = false;
  bool _isMuted = false;
  int _scheduledHours = 0;
  int _scheduledMinutes = 0;
  var _temperature = 25;
  late StreamSubscription<DeviceEvent> _deviceStreamSubscription;
  int _currentChannel = 0;
  int _currentVolume = 0;
  double _current = 0.0;
  double _power = 0.0;
  double _voltage = 0.0;

  Future<void> _saveDeviceStateToDevicePreferences(String firestoreId) async {
    print('[DEBUG] Salvando estado do dispositivo nas preferências');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOn_$firestoreId', _isOn);
    print(
        '[DEBUG] Salvo _isOn ID: $firestoreId em preferências: $_isOn'); // Verificar se o estado foi salvo
    await prefs.setInt('temperature', _temperature);
    print('[DEBUG] Salvo _temperature em preferências: $_temperature');
    await prefs.setInt('currentVolume', _currentVolume);
    print('[DEBUG] Salvo _currentVolume em preferências: $_currentVolume');
    await prefs.setInt('currentChannel', _currentChannel);
    print('[DEBUG] Salvo _currentChannel em preferências: $_currentChannel');
    await prefs.setBool('isMuted', _isMuted);
    print('[DEBUG] Salvo _isMuted em preferências: $_isMuted');

    // Salvar o horário agendado como string
    String scheduledTime = "$_scheduledHours:$_scheduledMinutes";
    print('[DEBUG] Agendamento salvo: $scheduledTime');
    await prefs.setString('scheduledTime', scheduledTime);
  }

  Future<void> _loadDeviceStateFromPreferences(String firestoreId) async {
    print('[DEBUG] Carregando preferências..');

    final prefs = await SharedPreferences.getInstance();

    // Carregar o estado do dispositivo das preferências
    bool? savedIsOn = prefs.getBool('isOn_$firestoreId');
    print('[DEBUG] Estado carregado _isOn, ID: $firestoreId: $savedIsOn');
    if (savedIsOn != null) {
      setState(() {
        _isOn = savedIsOn;
      });
    } else {
      print('OBS.: Nenhum estado salvo encontrado, utilizando valor padrão:');
    }

    int? savedTemperatureNullable = prefs.getInt('temperature');
    int savedTemperature =
        savedTemperatureNullable ?? widget.device.temperature;
    print('-> Estado carregado _temperature é: $savedTemperature');

    int savedVolume =
        prefs.getInt('currentVolume') ?? widget.device.currentVolume;
    print('-> Estado carregado _currentVolume é: $savedVolume');

    int savedChannel =
        prefs.getInt('currentChannel') ?? widget.device.currentChannel;
    print('-> Estado carregado _currentChannel é: $savedChannel');

    bool? savedMute = prefs.getBool('isMuted');
    print('-> Estado carregado _isMuted é: $savedMute');

    // Garantir que savedTemperature esteja dentro de um intervalo válido
    savedTemperature = (savedTemperature < 18 || savedTemperature > 30)
        ? 18
        : savedTemperature;

    // Carregar o horário agendado
    String? scheduledTime = prefs.getString('scheduledTime');
    print('[DEBUG] Carregando agendamento..: $scheduledTime');

    int loadedScheduledHours = 0;
    int loadedScheduledMinutes = 0;

    if (scheduledTime != null) {
      List<String> timeParts = scheduledTime.split(':');
      if (timeParts.length == 2) {
        loadedScheduledHours = int.tryParse(timeParts[0]) ?? 0;
        loadedScheduledMinutes = int.tryParse(timeParts[1]) ?? 0;

        DateTime now = DateTime.now();
        DateTime scheduledDateTime = DateTime(now.year, now.month, now.day,
            loadedScheduledHours, loadedScheduledMinutes);

        // Verifica se o horário programado já passou
        if (scheduledDateTime.isBefore(now)) {
          await _handlePastScheduledTime(prefs);

          final user = FirebaseAuth.instance.currentUser;
          final userId = user?.uid;
          DatabaseReference ref = FirebaseDatabase.instance
              .ref("users/$userId/air_conditioner_schedule");
          DatabaseEvent event = await ref.once();
          Map<String, dynamic> data =
              Map<String, dynamic>.from(event.snapshot.value as Map);

          bool turnOn = data['turnOn'] ??
              false;
          String status =
              data['status'] ?? '';

          await _updateDeviceStateBasedOnSchedule(turnOn, status);
        }
      }
    }

    if (_shouldRestoreState) {
      _restoreStateFromPreferences(
          savedIsOn ??
              false, // 'false' como valor padrão se 'savedIsOn' for nulo
          savedTemperature,
          savedVolume,
          savedChannel,
          savedMute ?? false,
          loadedScheduledHours,
          loadedScheduledMinutes);
    }
  }

  Future<void> _handlePastScheduledTime(SharedPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    DatabaseReference ref =
        FirebaseDatabase.instance.ref("users/$userId/air_conditioner_schedule");

    DatabaseEvent event = await ref.once();
    print(event.snapshot.value); // O valor dos dados

    await prefs.remove(
        'scheduledTime'); // Remove o valor do agendamento das SharedPreferences
  }

  Future<void> _updateDeviceStateBasedOnSchedule(
      bool turnOn, String status) async {
    print(
        '[DEBUG] _updateDeviceStateBasedOnSchedule called with turnOn: $turnOn, status: $status');
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    DatabaseReference ref =
        FirebaseDatabase.instance.ref("users/$userId/air_conditioner_schedule");

    if (turnOn == true && status == 'executed') {
      // Atualiza o estado do dispositivo para 'ligado'
      if (mounted) {
        setState(() {
          _isOn = true;
          _scheduledHours = 0;
          _scheduledMinutes = 0;
        });
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        widget.updateDevice(
          widget.device.copyWith(
            isOn: _isOn,
            scheduledHours: _scheduledHours,
            scheduledMinutes: _scheduledMinutes,
          ),
        );
      }
      // Atualizar o estado no Firebase para indicar que a ação foi concluída
      await ref.update({
        'status': 'completed',
      });
    } else if (turnOn == false && status == 'executed') {
      // Atualiza o estado do dispositivo para 'desligado'
      if (mounted) {
        setState(() {
          _isOn = false;
          _scheduledHours = 0;
          _scheduledMinutes = 0;
        });
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        widget.updateDevice(
          widget.device.copyWith(
            isOn: _isOn,
            scheduledHours: _scheduledHours,
            scheduledMinutes: _scheduledMinutes,
          ),
        );
      }
      // Atualizar o estado no Firebase para indicar que a ação foi concluída
      await ref.update({
        'status': 'completed',
      });
    } else {
      print(
          '[DEBUG] O status do dispositivo não foi atualizado porque o status não é "executed" ou porque faltam dados.');
    }
  }

  void _restoreStateFromPreferences(
    bool savedIsOn,
    int savedTemperature,
    int savedVolume,
    int savedChannel,
    bool savedMute,
    int loadedScheduledHours,
    int loadedScheduledMinutes,
  ) {
    if (!mounted) return;
    print(
        '[DEBUG] Restaurando estado do dispositivo com os seguintes valores:');
    print(
        '-> isOn: $savedIsOn, \n-> temperature: $savedTemperature, \n-> volume: $savedVolume, \n-> channel: $savedChannel, \n-> isMuted: $savedMute, \n-> scheduledHours: $loadedScheduledHours, \n-> scheduledMinutes: $loadedScheduledMinutes');
    setState(() {
      _isOn = savedIsOn;
      _temperature = savedTemperature;
      _currentVolume = savedVolume;
      _currentChannel = savedChannel;
      _scheduledHours = loadedScheduledHours;
      _scheduledMinutes = loadedScheduledMinutes;
      _isMuted = savedMute;
    });

    // Atualizar o dispositivo com os valores carregados
    widget.updateDevice(widget.device.copyWith(
        isOn: _isOn,
        temperature: _temperature,
        currentVolume: _currentVolume,
        currentChannel: _currentChannel,
        scheduledHours: _scheduledHours,
        scheduledMinutes: _scheduledMinutes,
        isMuted: _isMuted));

    print(
        '[DEBUG] Dispositivos foram atualizados e seus estados foram restaurados com sucesso!');
  }

  @override
  void initState() {
    super.initState();
    print("[DEBUG] Estado inicial chamado..");
    _initDeviceEventListening();
    _loadDeviceStateFromPreferences(widget.device.firestoreId);
  }

  void _initDeviceEventListening() {
    print('[DEBUG] Configurando o ouvinte de eventos do dispositivo..');

    final deviceEventService = DeviceEventService();

    // As funções 'onError' e 'onDone' são métodos nomeados passados para 'listen'.
    _deviceStreamSubscription =
        deviceEventService.deviceEventController.stream.listen(
      (DeviceEvent deviceEvent) {
        print(
            '[DEBUG] Evento recebido: o dispositivo está agora ${deviceEvent.isOn ? "ON" : "OFF"}');
        print('[DEBUG] Evento recebido: = ${deviceEvent.isSuccess}');
        if (mounted) {
          setState(() {
            _isOn = deviceEvent.isOn;
          });
          if (!deviceEvent.isSuccess) {
            print('[DEBUG] Tentando mostrar SnackBar');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(deviceEvent.errorMessage ?? 'Erro desconhecido.')));
          }
        }
      },
      onError: (error) {
        // Tratamento de erros quando algo dá errado ao escutar o stream.
        print('[DEBUG] A assinatura do stream encontrou um erro: $error');
      },
      onDone: () {
        // Callback chamado quando o stream é fechado.
        print('[DEBUG] A transmissão está fechada agora.');
      },
    );
  }

  Future<bool> _sendAirConditionerCommand(bool turnOn) async {
    // Defina a ação com base no valor booleano.
    final String action = turnOn ? "on" : "off";
    final String url = '$urlAUX/airconditioner/$action';

    try {
      // Faz a requisição POST para a URL definida.
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        // Se o servidor retornar um código de status 200, a operação foi bem-sucedida.
        print('[DEBUG] Ar condicionado esta: $action.');
        return true;
      } else {
        // Se o servidor retornar um código de status diferente de 200, houve uma falha.
        print(
            '[DEBUG] Ar condicionado esta: $action, falha ao iniciar. HTTP Status: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      // Qualquer exceção lançada durante a execução da solicitação será capturada aqui.
      print('[DEBUG] Erro ao controlar o ar condicionado: $error');
      return false;
    }
  }

  Future<void> _handleAirConditionerCommand(bool value) async {
    print('[DEBUG] Chamada para o ar condicionado com valor: $value');

    // Primeiro, tente enviar o comando e obtenha a confirmação de que foi bem-sucedido.
    bool success = await _sendAirConditionerCommand(value);

    if (success) {
      // Se o comando foi bem-sucedido, então atualizamos o estado e o dispositivo.
      if (mounted) {
        setState(() {
          _isOn =
              value; // Atualize o estado somente se a chamada da API foi bem-sucedida e o widget ainda está no widget tree.
        });
        print('[DEBUG] Estado do ar condicionado para: $_isOn');
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        // Notifique o widget pai sobre a atualização para que ele possa lidar com o estado global.
        widget.updateDevice(widget.device.copyWith(isOn: _isOn));
        print('[DEBUG] Dispositivo (ar) atualizado com estado: $_isOn');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comando enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setTemperature(int desiredTemperature) async {
    try {
      var response = await http.post(
        Uri.parse('$urlAUX/airconditioner/set_temperatura_$desiredTemperature'),
      );

      if (response.statusCode == 200) {
        print(
            '[DEBUG] Temperatura ajustada com sucesso para $desiredTemperatureº');
        setState(() {
          _temperature = desiredTemperature;
        });
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        widget.updateDevice(widget.device.copyWith(temperature: _temperature));
      } else {
        print('[DEBUG] Erro ao ajustar a temperatura: ${response.body}');
        // Se a chamada da API falhou..
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao enviar o comando para o dispositivo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      print('[DEBUG] Erro ao enviar o comando de temperatura: $error');
    }
  }

  Future<void> _scheduleAirConditionerCommand(
      bool turnOn, TimeOfDay time) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    if (userId == null) {
      return;
    }
    const String apiURL = "$urlAUX/schedule_air_conditioner";
    final response = await http.post(
      Uri.parse(apiURL),
      body: jsonEncode({
        'userId': userId,
        'turnOn': turnOn,
        'time':
            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}" // Formatar a hora para sempre enviar dois dígitos
      }),
      headers: {"Content-Type": "application/json"},
    );
    if (mounted) {
      if (response.statusCode == 200) {
        print("[DEBUG] Agendado com sucesso na API");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendado com sucesso!.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print("[DEBUG] Erro ao agendar na API");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '[DEBUG] Erro ao agendar! Verifique a disponibilidade da api.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTV(bool isOn) async {
    final response =
        await http.post(Uri.parse('$urlAUX/dispositivo/tv/energia'));

    // Se a chamada para a API foi bem-sucedida, logo será atualizado o estado local.
    if (response.statusCode == 200) {
      setState(() {
        _isOn = isOn; 
      });
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      widget.updateDevice(widget.device.copyWith(isOn: _isOn));
    } else {
      // Se houve um erro, você pode querer informar o usuário.
      print('[DEBUG] Erro ao alternar energia da TV');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Esta função cria um botão de ação estilizado.
  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: Colors.blueAccent, 
      iconSize: 30, 
    );
  }

  Future<void> _decreaseChannel() async {
    // Calcula o novo canal, mas não altera o estado ainda.
    int newChannel = max(1, _currentChannel - 1);

    // Faz a chamada para a API primeiro.
    final response =
        await http.post(Uri.parse('$urlAUX/dispositivo/tv/canal/menos'));

    // Verifica se a chamada foi bem-sucedida.
    if (response.statusCode == 200) {
      // Se foi bem-sucedida, atualiza o estado.
      setState(() {
        _currentChannel = newChannel;
      });

      // Notifica o dispositivo sobre a mudança.
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      widget.updateDevice(
          widget.device.copyWith(currentChannel: _currentChannel));
    } else {
      // Se falhou, registra o erro.
      print('[DEBUG] Erro ao diminuir o canal');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _increaseChannel() async {
    // Prepara para mudar o canal, mas não altera o estado ainda.
    int newChannel = _currentChannel + 1;

    // Faz a chamada para a API primeiro.
    final response =
        await http.post(Uri.parse('$urlAUX/dispositivo/tv/canal/mais'));

    // Verifica se a chamada foi bem-sucedida.
    if (response.statusCode == 200) {
      // Se foi bem-sucedida, atualiza o estado.
      setState(() {
        _currentChannel = newChannel;
      });
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      // Notifica o dispositivo sobre a mudança.
      widget.updateDevice(
          widget.device.copyWith(currentChannel: _currentChannel));
    } else {
      // Se falhou, registra o erro.
      print('[DEBUG] Erro ao aumentar o canal');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _decreaseVolume() async {
    // Calcula o novo volume, mas não altera o estado ainda.
    int newVolume = max(0, _currentVolume - 1);

    // Faz a chamada para a API primeiro.
    final response =
        await http.post(Uri.parse('$urlAUX/dispositivo/tv/volume/menos'));

    // Verifica se a chamada foi bem-sucedida.
    if (response.statusCode == 200) {
      // Se foi bem-sucedida, atualiza o estado.
      setState(() {
        _currentVolume = newVolume;
      });
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      // Atualiza o dispositivo com o novo volume.
      widget
          .updateDevice(widget.device.copyWith(currentVolume: _currentVolume));
    } else {
      // Se falhou, registra o erro.
      print('[DEBUG] Erro ao diminuir o volume');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _increaseVolume() async {
    // Calcula o novo volume, mas não altera o estado ainda. Garante que o volume não exceda 100.
    int newVolume = min(100, _currentVolume + 1);

    // Chamada para a API.
    final response =
        await http.post(Uri.parse('$urlAUX/dispositivo/tv/volume/mais'));

    // Verificando se a chamada foi bem-sucedida.
    if (response.statusCode == 200) {
      // Se a chamada foi bem-sucedida, atualiza o estado.
      setState(() {
        _currentVolume = newVolume;
      });
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      // Atualiza o dispositivo com o novo volume.
      widget
          .updateDevice(widget.device.copyWith(currentVolume: _currentVolume));
    } else {
      print('[DEBUG] Erro ao aumentar o volume');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMuteButton() {
    // Aqui, o ícone ainda depende do estado atual de "_isMuted".
    IconData icon = _isMuted ? Icons.volume_off : Icons.volume_up;
    return IconButton(
      icon: Icon(icon),
      onPressed: () {
        _toggleMute(); // Aqui chamamos a função sem alterar diretamente o estado.
      },
      color: Colors.blueAccent,
      iconSize: 30,
    );
  }

  Future<void> _toggleMute() async {
    // Calculamos o novo estado, mas não o aplicamos ainda.
    bool newMuteState = !_isMuted;

    // Tente atualizar o estado na API primeiro.
    final response = await http.post(Uri.parse('$urlAUX/dispositivo/tv/mudo'),
        body: {'isMuted': newMuteState.toString()});

    // Se a chamada para a API foi bem-sucedida, logo será atualizado o estado local.
    if (response.statusCode == 200) {
      setState(() {
        _isMuted = newMuteState;
      });
      await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
      widget.updateDevice(widget.device.copyWith(isMuted: _isMuted));
    } else {
      // Se houve um erro, você pode querer informar o usuário.
      print('[DEBUG] Erro ao alternar o mudo');
      print('[DEBUG] HTTP Status: ${response.statusCode}');
      // Se a chamada da API falhou..
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao enviar o comando para o dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleDevicePower(bool isOn) async {
    final String endpoint =
        isOn ? '/dispositivo/led/on' : '/dispositivo/led/off';
    final String uri = '$urlAUX$endpoint';

    try {
      final response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        print(
            '[DEBUG] Status HTTP OK!, dispositivo ${isOn ? 'ligado' : 'desligado'} com sucesso!');
        setState(() {
          _isOn = isOn;
        });
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        widget.updateDevice(widget.device.copyWith(isOn: _isOn));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comando enviado com sucesso!.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('[DEBUG] Erro ao alternar energia do LED!');
        print('[DEBUG] HTTP Status: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao enviar o comando para o dispositivo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar o comando: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePowerOutlet(bool isOn) async {
    const String uri = '$urlAUX/send_command';
    // Preparando o corpo da requisição
    final Map<String, dynamic> commandBody = {
      "commands": [
        {
          "code": "switch_1", // o código da ação que controla a tomada
          "value": isOn // true para ligar, false para desligar
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(uri),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(commandBody),
      );
      if (response.statusCode == 200) {
        print('[DEBUG] Comando enviado com sucesso!');
        setState(() {
          _isOn = isOn;
        });
        await _saveDeviceStateToDevicePreferences(widget.device.firestoreId);
        widget.updateDevice(widget.device.copyWith(isOn: _isOn));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comando enviado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('[DEBUG] Erro ao enviar comando para tomada: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao enviar o comando para o dispositivo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar o comando: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Função para obter o status da tomada.
  Future<void> _getPowerOutletStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final String uri = '$urlAUX/get_status?userId=$userId';

    try {
      final response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        print('[DEBUG] Status recebido com sucesso: ${response.body}');
        final data = json.decode(response.body);
        setState(() {
          // Utilize o método toDouble() para converter o valor para double
          _current = (data['result']
                      .firstWhere((e) => e['code'] == 'cur_current')['value']
                  as int)
              .toDouble();
          _power = ((data['result']
                          .firstWhere((e) => e['code'] == 'cur_power')['value']
                      as int) /
                  10)
              .toDouble();
          _voltage = ((data['result'].firstWhere(
                      (e) => e['code'] == 'cur_voltage')['value'] as int) /
                  10)
              .toDouble();
        });
      } else {
        print('[DEBUG] Erro ao obter status: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar o comando: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] Construindo o widget DeviceControlDialog');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior
            .opaque, // detecta toques em toda a área que não é coberta pelo DeviceControlDialog
        onTap: () {
          Navigator.of(context)
              .pop(); // Isso fecha o Dialog quando a área fora é tocada
        },
        child: Dialog(
          backgroundColor:
              Colors.transparent, // Isso torna o fundo do Dialog transparente
          elevation: 0.0, // Isso remove a sombra ao redor do Dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color.fromARGB(255, 255, 255, 255),
            ),
            padding: const EdgeInsets.all(15),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.device.name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      shadows: [
                        Shadow(
                          offset: const Offset(2.0, 2.0),
                          blurRadius: 3.0,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  if (widget.device.type == DeviceType.tv) ...[
                    SwitchListTile(
                      title: const Text('Ligado'),
                      value: _isOn,
                      onChanged: (value) async {
                        await _toggleTV(value);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIconButton(Icons.remove, _decreaseChannel),
                        const SizedBox(width: 20),
                        const Text('Canal', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 20),
                        _buildIconButton(Icons.add, _increaseChannel),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIconButton(Icons.remove, _decreaseVolume),
                        const SizedBox(width: 20),
                        const Text('Volume', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 20),
                        _buildIconButton(Icons.add, _increaseVolume),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMuteButton(), // constrói o botão de mudo
                      ],
                    ),
                  ] else if (widget.device.type ==
                      DeviceType.arCondicionado) ...[
                    DropdownButton<int>(
                      value: _temperature,
                      items: List.generate(13, (index) {
                        int tempValue = index + 18;
                        return DropdownMenuItem<int>(
                          value: tempValue,
                          child: Text('$tempValue°C'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          _setTemperature(value);
                        }
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Ligado'),
                      value: _isOn,
                      onChanged: _handleAirConditionerCommand,
                    ),
                    ListTile(
                        title: const Text('Programação:'),
                        trailing: Text(
                          "${widget.device.scheduledHours}:${widget.device.scheduledMinutes.toString().padLeft(2, '0')} ${widget.device.scheduledHours >= 12 ? 'PM' : 'AM'}",
                        ),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: widget.device.scheduledHours,
                              minute: widget.device.scheduledMinutes,
                            ),
                          );

                          // Continuamos após a escolha do tempo usando 'await'.
                          if (pickedTime != null) {
                            // Atualizar variáveis de estado antes de salvar nas preferências
                            setState(() {
                              _scheduledHours = pickedTime.hour;
                              _scheduledMinutes = pickedTime.minute;
                            });

                            // Agora chama a função para salvar o estado nas preferências
                            await _saveDeviceStateToDevicePreferences(
                                widget.device.firestoreId);

                            // Atualiza o dispositivo com o novo horário escolhido
                            final updatedDevice = widget.device.copyWith(
                              scheduledHours: pickedTime.hour,
                              scheduledMinutes: pickedTime.minute,
                            );

                            widget.updateDevice(updatedDevice);

                            if (mounted) {
                              final bool? turnOn = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Ligar ou desligar?'),
                                    content: const Text(
                                        'Você deseja ligar ou desligar o ar-condicionado no horário programado?'),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(true),
                                        child: const Text('Ligar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        child: const Text('Desligar'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (turnOn != null) {
                                await _scheduleAirConditionerCommand(
                                    turnOn, pickedTime);
                              }
                            } 
                          }
                        }),
                  ] else if (widget.device.type == DeviceType.lampada) ...[
                    SwitchListTile(
                        title: const Text('Ligado'),
                        value: _isOn,
                        onChanged: (bool value) {
                          _toggleDevicePower(
                              value); // Envie a requisição para o servidor
                        })
                  ] else if (widget.device.type == DeviceType.tomada) ...[
                    SwitchListTile(
                      title: const Text('Ligado'),
                      value: _isOn,
                      onChanged: (bool value) {
                        _togglePowerOutlet(
                            value); // Envie a requisição para o servidor
                      },
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Centraliza verticalmente na Column
                      crossAxisAlignment: CrossAxisAlignment
                          .center, // Centraliza horizontalmente na Column
                      children: [
                        ElevatedButton(
                          onPressed: _getPowerOutletStatus,
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.blueAccent),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            elevation: MaterialStateProperty.all(6),
                          ),
                          child: const Text(
                            'Status',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(
                            height: 10), // Adiciona espaço entre os elementos
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // Centraliza horizontalmente na Row
                          children: <Widget>[
                            const Icon(Icons.flash_on, color: Colors.yellow),
                            Text(
                              ' Corrente: ${_current.toStringAsFixed(2)} mA',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // Centraliza horizontalmente na Row
                          children: <Widget>[
                            const Icon(Icons.power, color: Colors.red),
                            Text(
                              ' Potência: ${_power.toStringAsFixed(2)} W',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .center, // Centraliza horizontalmente na Row
                          children: <Widget>[
                            const Icon(Icons.bolt, color: Colors.green),
                            Text(
                              ' Voltagem: ${_voltage.toStringAsFixed(2)} V',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    )
                  ] else
                    const Text('Outro Tipo de Dispositivo'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('[DEBUG] Alterado as dependências.');
  }

  @override
  void didUpdateWidget(DeviceControlDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[DEBUG] Atualizado widget.');
  }

  @override
  void dispose() {
    // É importante sempre cancelar as assinaturas de stream para liberar recursos
    // quando o estado for descartado. Isso evita vazamentos de memória.
    _deviceStreamSubscription.cancel();
    super.dispose();
  }
}
