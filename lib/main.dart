//@dart= 2.9

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'hexConverter.dart';
import 'splashScreen.dart';

//Telephony
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called");
}

//End

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PROJET_GPS_ENSGEP',
      initialRoute: 'Splash',
      routes: {
        'Splash': (ctx)=> SplashScreen(),
        '/': (ctx)=> HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool show = false;
  bool showNotif = false;
  bool sendingRequest;
  bool sendingRingRequest = false;
  bool bellState = false;

  //Notification Utilities

  FlutterLocalNotificationsPlugin localNotification =
      FlutterLocalNotificationsPlugin();

  Future<void> showNotification() async {
    var androidDetails = AndroidNotificationDetails(
        "channelId", 'Ma notification', "Message de la notification",
        importance: Importance.high,
        styleInformation: BigTextStyleInformation(''));
    var iosDetails = IOSNotificationDetails();
    var generalDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await localNotification.show(
        2,
        'Votre appareil n\'est plus loin',
        'Vous êtes à moins de 5m de votre appareil. Retournez dans l\'application pour le faire sonner afin de le retrouver',
        generalDetails);
    await localNotification.periodicallyShow(
        1,
        'Votre appareil n\'est plus loin',
        'Vous êtes à moins de 5m de votre appareil. Retournez dans l\'application pour le faire sonner afin de le retrouver',
        RepeatInterval.everyMinute,
        generalDetails);
  }

  Future<void> cancelNotification() async {
    await localNotification.cancelAll();
  }
  //End of notification Utilities
  //Geolocation Utilities

  Future<void> getcurrentLocation() async {
    final position =
        await Geolocator.getCurrentPosition(timeLimit: Duration(minutes: 2));
    final lastPosition = await Geolocator.getLastKnownPosition();
    print("Last location: $lastPosition");
    print("Actual location: $position");
  }

  Stream<Position> streamcurrentLocation() async* {
    yield* Geolocator.getPositionStream(
      intervalDuration: Duration(seconds: 2),
    );
  }
  //End og Geolocation Utilities

  //Telephony utilities
  String _message = "";
  final telephony = Telephony.instance;
  Map<String, double> location = {'Lat': null, 'Long': null};
  @override
  void dispose() {
    localNotification.cancelAll();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    sendingRequest = false;
    var androidInitialize = AndroidInitializationSettings('locate');
    var iosInitialize = IOSInitializationSettings();
    var initializationSetting =
        InitializationSettings(android: androidInitialize, iOS: iosInitialize);
    localNotification.initialize(initializationSetting);
    initPlatformState();
  }

  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.body ?? "Error reading message body.";
    });
  }

  onSendStatus(SendStatus status) {
    setState(() {
      _message = status == SendStatus.SENT ? "sent" : "delivered";
    });
  }

  Future<void> initPlatformState() async {
    final bool result = await telephony.requestPhoneAndSmsPermissions;

    if (result != null && result) {
      telephony.listenIncomingSms(
          onNewMessage: onMessage, onBackgroundMessage: onBackgroundMessage);
    }

    if (!mounted) return;
  }

  //Example End

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        headers: <String, String>{'my_header_key': 'my_header_value'},
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      sendingRequest = true;
    });
    print('Start fetching');
    //final url = Uri.https("savenums-default-rtdb.firebaseio.com", "/Lat.json");
    final url =
        Uri.https("savenums-default-rtdb.firebaseio.com", "/Location.json");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          location = {
            'Lat': responseData['Lat'],
            'Long': responseData['Long']
          };
        });
      }
    } catch (e) {
      setState(() {
        sendingRequest = false;
      });
      if (e
          .toString()
          .contains('OS Error: No address associated with hostname')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Une erreur s\'est produite. Veuillez vérifier votre connexion internet'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ));
      }
      if (e.toString().contains('Connection timed out')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Le temps maximum d\'attente est atteint. Veuillez en lancer une autre'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ));
      }
      print(e);
    } finally {
      setState(() {
        sendingRequest = false;
        print('Finish fetching');
      });
    }
  }

  Future<void> ringTheBell() async {
    setState(() {
      sendingRingRequest = true;
    });
    if(bellState){
      setState(() {
        bellState = false;
      });
    }else{
      bellState = true;
    }
    print('Start sending request');
    final url =
        Uri.https("savenums-default-rtdb.firebaseio.com", "/BellState.json");
    try {
      final response = await http.put(url, body:jsonEncode({'bellRinging':bellState}));
      print(response.statusCode.toString());
      if (response.statusCode == 200) {
        print('Alright');
      }
    } catch (e) {
      print("Error");
      setState(() {
        sendingRingRequest = false;
      });
      if (e
          .toString()
          .contains('OS Error: No address associated with hostname')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Une erreur s\'est produite. Veuillez vérifier votre connexion internet'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()
          ),
        ));
      }
      if (e.toString().contains('Connection timed out')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Le temps maximum d\'attente est atteint. Veuillez en lancer une autre'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ));
      }
      print(e);
    } finally {
      setState(() {
        sendingRingRequest = false;
        print('Finish pushing');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PROJET_GPS_ENSGEP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),
        centerTitle: true,
        backgroundColor: HexColor.fromHex('#222059'),
      ),
      body: Center(
        child: sendingRequest
            ? CircularProgressIndicator(backgroundColor:HexColor.fromHex('#222059') ,)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(HexColor.fromHex('#222059'))
                    ),
                      onPressed: () {
                        try {
                          _fetchLocation().then((value) {
                            if (location['Lat'] != null) {
                              setState(() {
                                show = true;
                                showNotif = true;
                              });
                            }
                          });
                        } catch (e) {
                          print(e.toString());
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(5),
                        color: HexColor.fromHex('#222059'),
                          alignment: Alignment.center,
                          width: MediaQuery.of(context).size.width / 1.6,
                          child: Column(
                            children: [
                              Text(
                                'Actualiser la position de l\'objet',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 20),
                              ),
                            ],
                          ))),
                 /*  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        show = true;
                      });
                      /*  telephony.sendSms(
                            to: '+22966613755', message: 'Test 1'); */
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width / 2,
                      child: Text('Requête sms'),
                    ),
                  ), */
                  SizedBox(height: 20),
                  if (show)
                    Container(
                      height: 100,
                      child: StreamBuilder(
                          stream: streamcurrentLocation(),
                          initialData: Position(
                              longitude: 0,
                              latitude: 0,
                              timestamp: DateTime.now(),
                              accuracy: 0,
                              altitude: 0,
                              heading: 0,
                              speed: 0,
                              speedAccuracy: 0),
                          builder: (context, snapshot) {
                            final position = snapshot.data as Position;
                            double lat1 = position.latitude * pi / 180;
                            double long1 = position.longitude * pi / 180;
                            double lat2 = location['Lat'] * pi / 180;
                            double long2 = location['Long'] * pi / 180;
                            int rayon = 6367445;
                            double distance = rayon *
                                acos((sin(lat1)) * (sin(lat2)) +
                                    (cos(lat1)) *
                                        (cos(lat2)) *
                                        cos(long2 - long1));
                            if (distance < 10) {
                              if (showNotif) {
                                print('1');
                                showNotification();
                                showNotif = false;
                              }
                            } else {
                              print('2');
                              showNotif = true;
                            }
                            print('Distance = $distance');
                            return Text(
                                'Vous êtes à environ ${distance.toStringAsFixed(3)}m du dispositif');
                          }),
                    ),
                ],
              ),
      ),
      floatingActionButton: Row(
        children: [
          SizedBox(
            width: 30,
          ),
          if (show)
            FloatingActionButton(
              backgroundColor: HexColor.fromHex('#222059'),
                onPressed: () {
                  cancelNotification();
                  setState(() {
                    location['Lat'] = null;
                    location['Lng'] = null;
                    show = false;
                  });
                },
                tooltip: 'Objet retrouvé',
                child: Icon(Icons.check)),
          Spacer(),
          if (show)
            FloatingActionButton(
              backgroundColor: HexColor.fromHex('#222059'),
              onPressed: () {
                try {
                  ringTheBell();
                } catch (e) {
                  print(e.toString());
                }
                //Make de module ring
              },
              tooltip: 'Faire sonner le dispositif',
              child: sendingRingRequest
                  ? CircularProgressIndicator(
                      backgroundColor: Colors.white,
                    ) :bellState?Icon(Icons.notifications_active_rounded)
                  : Icon(Icons.notifications_active_outlined),
            ),
          Spacer(),
          FloatingActionButton(
            backgroundColor: HexColor.fromHex('#222059'),
              onPressed: location['Lat'] == null
                  ? () {}
                  : () {
                      _launchInBrowser(
                          'http://maps.google.com?q=${location['Lat'].toString()},${location['Long'].toString()}');
                      /*  Navigator.of(context)
                  .push(MaterialPageRoute(builder: (context) => GoogleMapScreen())); */
                    },
              tooltip: 'Afficher la carte',
              child: Icon(Icons.location_on_outlined)),
        ],
      ),
    );
  }
}
