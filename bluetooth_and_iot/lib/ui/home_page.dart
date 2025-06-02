import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FlutterReactiveBle ble;
  StreamSubscription<DiscoveredDevice>? scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  Timer? _readTimer;
  QualifiedCharacteristic? _characteristic;

  String temperature = '—';
  String lastUpdated = '—';
  bool connecting = false;
  bool connected = false;

  final List<String> log = [];

  final Uuid serviceUuid = Uuid.parse("12345678-1234-5678-1234-56789abcdef0");
  final Uuid charUuid = Uuid.parse("87654321-4321-6789-4321-fedcba987654");

  @override
  void initState() {
    super.initState();
    ble = context.read<FlutterReactiveBle>();
  }

  void startScan() {
    setState(() {
      connecting = true;
      temperature = '—';
      lastUpdated = '—';
      log.clear();
    });

    scanSub = ble.scanForDevices(withServices: []).listen((d) {
      if (d.name == "ESP32-TEMP") {
        scanSub?.cancel();
        connectToDevice(d);
      }
    });
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    _connection = ble.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        print("Устройство подключено");

        _characteristic = QualifiedCharacteristic(
          characteristicId: charUuid,
          serviceId: serviceUuid,
          deviceId: device.id,
        );

        await readTemperature();

        _readTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
          await readTemperature();
        });

        setState(() {
          connecting = false;
          connected = true;
        });

      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        print("Устройство отключено");
        _readTimer?.cancel();
        setState(() {
          connecting = false;
          connected = false;
        });
      }
    }, onError: (e) {
      print("Ошибка подключения: $e");
      _readTimer?.cancel();
      setState(() {
        connecting = false;
        connected = false;
      });
    });
  }

  Future<void> readTemperature() async {
    if (_characteristic == null) return;
    try {
      final value = await ble.readCharacteristic(_characteristic!);
      final decoded = utf8.decode(value);
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      print('Прочитано: $decoded');

      setState(() {
        temperature = decoded;
        lastUpdated = timeStr;

        log.insert(0, "$timeStr — $decoded");
        if (log.length > 5) {
          log.removeLast();
        }
      });
    } catch (e) {
      print("Ошибка чтения температуры: $e");
      setState(() {
        temperature = 'Ошибка';
        lastUpdated = '—';
      });
    }
  }

  void disconnect() {
    _connection?.cancel();
    _readTimer?.cancel();
    setState(() {
      connected = false;
      connecting = false;
      temperature = '—';
      lastUpdated = '—';
      _characteristic = null;
    });
  }

  @override
  void dispose() {
    scanSub?.cancel();
    _connection?.cancel();
    _readTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE IoT Температура")),
      body: Center(
        child: connecting
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Температура:", style: Theme.of(context).textTheme.headlineSmall),
            Text(temperature, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            Text("Обновлено: $lastUpdated"),
            const SizedBox(height: 20),
            connected
                ? ElevatedButton(
              onPressed: disconnect,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Отключиться"),
            )
                : ElevatedButton(
              onPressed: startScan,
              child: const Text("Сканировать и подключиться"),
            ),
            const SizedBox(height: 30),
            Text("Последние значения:"),
            ...log.map((entry) => Text(entry)).toList(),
          ],
        ),
      ),
    );
  }
}
