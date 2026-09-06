import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'firebase_options.dart';

// ============================================================
// FIREBASE BACKGROUND MESSAGE HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

// ============================================================
// NOTIFICATION CHANNEL
// ============================================================

// New channel ID so Android does not reuse old/muted settings.
const String emergencyChannelId = 'home_care_emergency_v2';
const String emergencyChannelName = 'Home Care Emergency Alerts';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// ============================================================
// FIREBASE
// ============================================================

final FirebaseFirestore firestore = FirebaseFirestore.instance;

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await initializeNotifications();

  await setupFirebaseMessaging();

  runApp(const HomeCareApp());
}

// ============================================================
// INITIALIZE NOTIFICATIONS
// ============================================================

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Notification tapped.
    },
  );

  // IMPORTANT:
  // This cannot be const because Int64List.fromList()
  // is not a compile-time constant.
  final AndroidNotificationChannel emergencyChannel =
      AndroidNotificationChannel(
    emergencyChannelId,
    emergencyChannelName,
    description: 'Critical Home Care emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([
      0,
      1200,
      400,
      1200,
      400,
      1200,
      400,
      1200,
      400,
      1200,
    ]),
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    emergencyChannel,
  );
}

// ============================================================
// FIREBASE CLOUD MESSAGING
// ============================================================

Future<void> setupFirebaseMessaging() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Android 13+ notification permission.
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get FCM token.
  final String? token = await messaging.getToken();

  if (token != null) {
    await firestore
        .collection('elderly_users')
        .doc('elderly_001')
        .set(
      {
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // Update token whenever Firebase refreshes it.
  messaging.onTokenRefresh.listen(
    (String newToken) async {
      await firestore
          .collection('elderly_users')
          .doc('elderly_001')
          .set(
        {
          'fcmToken': newToken,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    },
  );

  // Foreground FCM messages.
  FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) async {
      final String title =
          message.notification?.title ?? 'HOME CARE EMERGENCY';

      final String body =
          message.notification?.body ??
              'Emergency assistance required';

      await showEmergencyNotification(
        title: title,
        message: body,
      );
    },
  );
}

// ============================================================
// EMERGENCY NOTIFICATION
// SOUND + REPEATING VIBRATION
// ============================================================

Future<void> showEmergencyNotification({
  required String title,
  required String message,
}) async {
  // ----------------------------------------------------------
  // VIBRATION
  // ----------------------------------------------------------

  try {
    final bool? hasVibrator = await Vibration.hasVibrator();

    if (hasVibrator == true) {
      await Vibration.cancel();

      await Vibration.vibrate(
        pattern: const [
          0,
          1200,
          400,
          1200,
          400,
          1200,
          400,
          1200,
          400,
          1200,
        ],
        repeat: 0,
      );
    }
  } catch (_) {
    // Ignore vibration errors.
  }

  // ----------------------------------------------------------
  // NOTIFICATION
  // ----------------------------------------------------------

  final AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    emergencyChannelId,
    emergencyChannelName,
    channelDescription: 'Critical Home Care emergency alerts',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    ticker: 'HOME CARE EMERGENCY',
    vibrationPattern: Int64List.fromList([
      0,
      1200,
      400,
      1200,
      400,
      1200,
      400,
      1200,
      400,
      1200,
    ]),
  );

  final NotificationDetails notificationDetails =
      NotificationDetails(
    android: androidDetails,
  );

  await localNotifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: message,
    notificationDetails: notificationDetails,
  );
}

// ============================================================
// STOP EMERGENCY ALERT
// ============================================================

Future<void> stopEmergencyAlert() async {
  try {
    await Vibration.cancel();
  } catch (_) {}

  try {
    await localNotifications.cancelAll();
  } catch (_) {}
}

// ============================================================
// HAZARD TITLE
// ============================================================

String hazardTitle(String hazard) {
  switch (hazard.toLowerCase()) {
    case 'fire':
      return '🔥 FIRE DETECTED';

    case 'gas':
      return '💨 GAS LEAK DETECTED';

    case 'smoke':
      return '🚨 SMOKE DETECTED';

    default:
      return '⚠️ HOME HAZARD';
  }
}

// ============================================================
// APP
// ============================================================

class HomeCareApp extends StatelessWidget {
  const HomeCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Care',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
      ),
      home: const ElderlyHomePage(),
    );
  }
}

// ============================================================
// ELDERLY HOME PAGE
// ============================================================

class ElderlyHomePage extends StatefulWidget {
  const ElderlyHomePage({super.key});

  @override
  State<ElderlyHomePage> createState() => _ElderlyHomePageState();
}

class _ElderlyHomePageState extends State<ElderlyHomePage> {
  // ==========================================================
  // STATUS
  // ==========================================================

  String status = 'Everything is okay';

  bool sending = false;

  bool emergencyActive = false;

  // ==========================================================
  // HAZARD
  // ==========================================================

  String? hazardType;

  String? hazardMessage;

  String? hazardSeverity;

  bool hazardAcknowledged = false;

  // ==========================================================
  // CARETAKER REQUEST
  // ==========================================================

  bool caretakerAsking = false;

  String caretakerQuestion = '';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      hazardSubscription;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      careRequestSubscription;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    listenToHazards();

    listenToCaretakerRequest();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    hazardSubscription?.cancel();

    careRequestSubscription?.cancel();

    Vibration.cancel();

    super.dispose();
  }

  // ==========================================================
  // LISTEN TO FIRESTORE HAZARD
  // ==========================================================

  void listenToHazards() {
    hazardSubscription = firestore
        .collection('hazards')
        .doc('home_001')
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) async {
        if (!snapshot.exists) {
          return;
        }

        final Map<String, dynamic>? data = snapshot.data();

        if (data == null) {
          return;
        }

        final bool active = data['active'] == true;

        final String hazard =
            data['hazard']?.toString().toLowerCase() ?? '';

        final String message =
            data['message']?.toString() ??
                'A hazard has been detected.';

        final String severity =
            data['severity']?.toString() ?? 'critical';

        // ------------------------------------------------------
        // ACTIVE HAZARD
        // ------------------------------------------------------

        if (active && hazard.isNotEmpty) {
          final bool isNewHazard =
              hazardType != hazard || !emergencyActive;

          if (!mounted) return;

          setState(() {
            hazardType = hazard;
            hazardMessage = message;
            hazardSeverity = severity;
            emergencyActive = true;
            hazardAcknowledged = false;
            status = hazardTitle(hazard);
          });

          // Only trigger alert once for a new hazard.
          if (isNewHazard) {
            await showEmergencyNotification(
              title: hazardTitle(hazard),
              message: message,
            );

            if (!mounted) return;

            showHazardDialog(
              hazard,
              message,
            );
          }
        }

        // ------------------------------------------------------
        // HAZARD CLEARED
        // ------------------------------------------------------

        else {
          await stopEmergencyAlert();

          if (!mounted) return;

          setState(() {
            hazardType = null;
            hazardMessage = null;
            hazardSeverity = null;
            emergencyActive = false;
            hazardAcknowledged = false;

            if (!sending) {
              status = 'Everything is okay';
            }
          });
        }
      },
    );
  }

  // ==========================================================
  // HAZARD DIALOG
  // ==========================================================

  void showHazardDialog(
    String hazard,
    String message,
  ) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                hazardTitle(hazard),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Text(
                message,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await stopEmergencyAlert();

                      if (!mounted) return;

                      setState(() {
                        hazardAcknowledged = true;
                        hazardType = null;
                        hazardMessage = null;
                        hazardSeverity = null;
                        emergencyActive = false;
                        status = 'Everything is okay';
                      });

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'I UNDERSTAND',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // CARETAKER REQUEST LISTENER
  // ==========================================================

  void listenToCaretakerRequest() {
    careRequestSubscription = firestore
        .collection('care_requests')
        .doc('elderly_001')
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        if (!snapshot.exists) {
          return;
        }

        final Map<String, dynamic>? data = snapshot.data();

        if (data == null) {
          return;
        }

        final String requestStatus =
            data['status']?.toString() ?? '';

        final String question =
            data['question']?.toString() ?? 'Are you okay?';

        if (requestStatus == 'pending') {
          if (!mounted) return;

          setState(() {
            caretakerAsking = true;
            caretakerQuestion = question;
          });

          showCaretakerDialog(question);
        }
      },
    );
  }

  // ==========================================================
  // CARETAKER QUESTION DIALOG
  // ==========================================================

  void showCaretakerDialog(String question) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                '👨‍⚕️ CARETAKER',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                question,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                // ------------------------------------------------
                // I'M OKAY
                // ------------------------------------------------

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await answerCaretaker('okay');

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '🟢  I\'M OKAY',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------
                // I NEED HELP
                // ------------------------------------------------

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await answerCaretaker('help');

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '🔴  I NEED HELP',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // ANSWER CARETAKER
  // ==========================================================

  Future<void> answerCaretaker(String response) async {
    await firestore
        .collection('care_requests')
        .doc('elderly_001')
        .set(
      {
        'status': 'answered',
        'response': response,
        'respondedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    setState(() {
      caretakerAsking = false;
    });
  }

  // ==========================================================
  // I'M OKAY
  // ==========================================================

  Future<void> confirmOkay() async {
    if (sending) return;

    await stopEmergencyAlert();

    if (!mounted) return;

    setState(() {
      sending = true;
      emergencyActive = false;
      hazardAcknowledged = false;
      hazardType = null;
      hazardMessage = null;
      hazardSeverity = null;
      status = 'Sending...';
    });

    try {
      await firestore
          .collection('elderly_users')
          .doc('elderly_001')
          .set(
        {
          'status': 'okay',
          'message': 'I am okay',
          'emergency': false,
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        status = 'Everything is okay';
        emergencyActive = false;
        sending = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        status = 'Could not send';
        sending = false;
      });
    }
  }

  // ==========================================================
  // EMERGENCY BUTTON
  // ==========================================================

  Future<void> emergency() async {
    if (sending) return;

    if (!mounted) return;

    setState(() {
      sending = true;
      emergencyActive = true;
      hazardAcknowledged = false;
      hazardType = null;
      hazardMessage = null;
      hazardSeverity = null;
      status = 'EMERGENCY ALERT SENT';
    });

    try {
      await firestore
          .collection('elderly_users')
          .doc('elderly_001')
          .set(
        {
          'status': 'emergency',
          'message': 'Emergency assistance required',
          'emergency': true,
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Local emergency alarm.
      await showEmergencyNotification(
        title: '🚨 HOME CARE EMERGENCY',
        message: 'Emergency assistance required',
      );

      if (!mounted) return;

      setState(() {
        sending = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        status = 'Emergency failed';
        sending = false;
      });
    }
  }

  // ==========================================================
  // STATUS CARD
  // ==========================================================

  Widget buildStatusCard() {
    final bool danger =
        emergencyActive ||
        hazardType != null ||
        status.contains('EMERGENCY') ||
        status.contains('DETECTED');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: danger
            ? Colors.red.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: danger
              ? Colors.red.shade300
              : Colors.green.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            danger
                ? Icons.warning_rounded
                : Icons.check_circle_rounded,
            size: 58,
            color: danger ? Colors.red : Colors.green,
          ),

          const SizedBox(height: 12),

          Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: danger
                  ? Colors.red.shade800
                  : Colors.green.shade800,
            ),
          ),

          if (hazardType != null) ...[
            const SizedBox(height: 10),

            Text(
              hazardMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // CARETAKER REQUEST CARD
  // ==========================================================

  Widget buildCaretakerRequestCard() {
    if (!caretakerAsking) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_pin,
            size: 50,
            color: Colors.blue,
          ),

          const SizedBox(height: 8),

          const Text(
            'Your caretaker is asking:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            caretakerQuestion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await answerCaretaker('okay');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'I\'M OKAY',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await answerCaretaker('help');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'I NEED HELP',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOME CARE',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Elderly Safety System',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ------------------------------------------------
              // GREETING
              // ------------------------------------------------

              const Text(
                'Hello 👋',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                emergencyActive
                    ? 'Please stay safe.'
                    : 'How are you feeling today?',
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 25),

              // ------------------------------------------------
              // STATUS
              // ------------------------------------------------

              buildStatusCard(),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // CARETAKER REQUEST
              // ------------------------------------------------

              buildCaretakerRequestCard(),

              const SizedBox(height: 25),

              // ------------------------------------------------
              // I'M OKAY
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 75,
                child: ElevatedButton(
                  onPressed: sending ? null : confirmOkay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    '🟢  I AM OKAY',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ------------------------------------------------
              // EMERGENCY
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 85,
                child: ElevatedButton(
                  onPressed: sending ? null : emergency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    '🚨  EMERGENCY',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ------------------------------------------------
              // FIREBASE CONNECTION
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_done,
                      color: Colors.green,
                      size: 30,
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Firebase Connection',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              Center(
                child: Text(
                  'Your safety matters ❤️',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}