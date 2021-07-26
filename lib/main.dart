import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:bluetooth_enable/bluetooth_enable.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  BluetoothEnable.enableBluetooth.then((value) {
    if (value == "true") {
      return runApp(MyApp());
    }
  });

  //runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Skinuvita BLE Demo',
        theme: ThemeData(
          appBarTheme: AppBarTheme(centerTitle: true),
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Skinuvita'),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();
  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _writeController = TextEditingController();
  BluetoothDevice _connectedDevice;
  List<BluetoothService> _services;
  bool _switchValue = false;
  String _switchValString = '';
  List<int> _currentStatus;
  BluetoothCharacteristic characteristicWrite;
  BluetoothCharacteristic characteristicRead;

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }

  // Scan the available Bluetooth Devices
  // Only show the devices named 'Skinuvita'
  ListView _buildListViewOfSkinuvitaDevices() {
    List<Container> containers = new List<Container>();
    for (BluetoothDevice device in widget.devicesList) {
      if (device.name == 'Skinuvita') {
        containers.add(
          Container(
            height: 50,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                          device.name == '' ? '(unknown device)' : device.name),
                      Text(device.id.toString()),
                    ],
                  ),
                ),
                FlatButton(
                  color: Colors.blue,
                  child: Text(
                    'Connect',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    widget.flutterBlue.stopScan();
                    try {
                      await device.connect();
                    } catch (e) {
                      if (e.code != 'already_connected') {
                        throw e;
                      }
                    } finally {
                      _services = await device.discoverServices();
                      for (BluetoothService service in _services) {
                        for (BluetoothCharacteristic characteristic
                            in service.characteristics) {
                          if (characteristic.properties.write) {
                            characteristicWrite = characteristic;
                          }
                          if (characteristic.properties.read) {
                            characteristicRead = characteristic;
                          }
                        }
                      }
                    }
                    setState(() {
                      _connectedDevice = device;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  Widget controlDevice() {
    return Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(40.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Current Status",
                  style: TextStyle(fontSize: 18.0),
                ),
                Icon(Icons.circle),
              ],
            ),
            new TextField(
              controller: _writeController,
              decoration:
                  new InputDecoration(labelText: "Enter the time in Seconds"),
            ),
            CupertinoSwitch(
              value: _switchValue,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _switchValue = value;
                    _switchValString = '1';
                  } else {
                    _switchValue = value;
                    _switchValString = '0';
                  }
                });
              },
            ),
            new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    characteristicWrite.write(utf8.encode(
                        _switchValString + ' ' + _writeController.value.text));
                  },
                  child: Text('Start'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    characteristicWrite.write(utf8.encode('0' + ' ' + '0'));
                  },
                  child: Text('Stop'),
                )
              ],
            ),
          ],
        ));
  }

  Widget _buildView() {
    if (_connectedDevice != null) {
      return controlDevice();
    }
    return _buildListViewOfSkinuvitaDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildView());
}
