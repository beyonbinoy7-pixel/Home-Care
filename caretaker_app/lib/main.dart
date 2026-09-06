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
// FIREBASE
// ============================================================

final FirebaseFirestore firestore = FirebaseFirestore.instance;

// ============================================================
// NOTIFICATION CHANNEL
// ============================================================

const String emergencyChannelId = 'caretaker_emergency_v2';
const String emergencyChannelName =
    'Home Care Caretaker Emergency Alerts';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// ============================================================
// BACKGROUND FCM HANDLER
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

  runApp(const CaretakerApp());
}

// ============================================================
// NOTIFICATIONS INITIALIZATION
// ============================================================

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings =
      InitializationSettings(
    android: androidSettings,
  );

  await localNotifications.initialize(
    settings: settings,
    onDidReceiveNotificationResponse:
        (NotificationResponse response) {
      // Notification tapped.
    },
  );

  final AndroidNotificationChannel emergencyChannel =
      AndroidNotificationChannel(
    emergencyChannelId,
    emergencyChannelName,
    description:
        'Critical emergency alerts for the caretaker',
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

  final AndroidFlutterLocalNotificationsPlugin?
      androidPlugin =
      localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    emergencyChannel,
  );
}

// ============================================================
// FCM
// ============================================================

Future<void> setupFirebaseMessaging() async {
  final FirebaseMessaging messaging =
      FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final String? token =
      await messaging.getToken();

  if (token != null) {
    await firestore
        .collection('caretaker_users')
        .doc('caretaker_001')
        .set(
      {
        'fcmToken': token,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  messaging.onTokenRefresh.listen(
    (String newToken) async {
      await firestore
          .collection('caretaker_users')
          .doc('caretaker_001')
          .set(
        {
          'fcmToken': newToken,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    },
  );

  FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) async {
      final String title =
          message.notification?.title ??
              'HOME CARE ALERT';

      final String body =
          message.notification?.body ??
              'Please check the elderly person.';

      await showCaretakerNotification(
        title: title,
        message: body,
      );
    },
  );
}

// ============================================================
// CARETAKER ALERT
// SOUND + REPEATING VIBRATION + NOTIFICATION
// ============================================================

Future<void> showCaretakerNotification({
  required String title,
  required String message,
}) async {
  // ----------------------------------------------------------
  // VIBRATION
  // ----------------------------------------------------------

  try {
    final bool? hasVibrator =
        await Vibration.hasVibrator();

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
  } catch (_) {}

  // ----------------------------------------------------------
  // NOTIFICATION
  // ----------------------------------------------------------

  final AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    emergencyChannelId,
    emergencyChannelName,
    channelDescription:
        'Critical emergency alerts for caretaker',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    ticker: 'HOME CARE ALERT',
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

  final NotificationDetails details =
      NotificationDetails(
    android: androidDetails,
  );

  await localNotifications.show(
    id: DateTime.now()
            .millisecondsSinceEpoch ~/
        1000,
    title: title,
    body: message,
    notificationDetails: details,
  );
}

// ============================================================
// STOP ALERT
// ============================================================

Future<void> stopCaretakerAlert() async {
  try {
    await Vibration.cancel();
  } catch (_) {}

  try {
    await localNotifications.cancelAll();
  } catch (_) {}
}

// ============================================================
// APP
// ============================================================

class CaretakerApp extends StatelessWidget {
  const CaretakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Care - Caretaker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF5F7FA),
      ),
      home: const CaretakerHomePage(),
    );
  }
}

// ============================================================
// CARETAKER PAGE
// ============================================================

class CaretakerHomePage
    extends StatefulWidget {
  const CaretakerHomePage({super.key});

  @override
  State<CaretakerHomePage> createState() =>
      _CaretakerHomePageState();
}

class _CaretakerHomePageState
    extends State<CaretakerHomePage> {

  bool asking = false;

  // Track previous states so we don't vibrate repeatedly
  // every time Firestore sends another snapshot.
  bool previousEmergency = false;
  bool previousHazard = false;
  String previousHazardType = '';

  String previousResponse = '';

  // ==========================================================
  // FIRESTORE REFERENCES
  // ==========================================================

  DocumentReference<Map<String, dynamic>>
      get elderlyReference =>
          firestore
              .collection('elderly_users')
              .doc('elderly_001');

  DocumentReference<Map<String, dynamic>>
      get hazardReference =>
          firestore
              .collection('hazards')
              .doc('home_001');

  DocumentReference<Map<String, dynamic>>
      get careRequestReference =>
          firestore
              .collection('care_requests')
              .doc('elderly_001');

  // ==========================================================
  // ASK ELDERLY
  // ==========================================================

  Future<void> askAreYouOkay() async {
    if (asking) return;

    setState(() {
      asking = true;
    });

    try {
      await careRequestReference.set(
        {
          'question': 'Are you okay?',
          'status': 'pending',
          'response': null,
          'requestedAt':
              FieldValue.serverTimestamp(),
          'respondedAt': null,
        },
        SetOptions(merge: true),
      );

      await stopCaretakerAlert();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: const Text(
            'Question sent to the elderly person',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor:
              Colors.blue.shade700,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send the question',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          asking = false;
        });
      }
    }
  }

  // ==========================================================
  // HAZARD
  // ==========================================================

  String hazardTitle(String hazard) {
    switch (hazard.toLowerCase()) {
      case 'fire':
        return 'FIRE DETECTED';

      case 'gas':
        return 'GAS LEAK DETECTED';

      case 'smoke':
        return 'SMOKE DETECTED';

      default:
        return 'HOME HAZARD DETECTED';
    }
  }

  String hazardSubtitle(String hazard) {
    switch (hazard.toLowerCase()) {
      case 'fire':
        return 'Fire or flame detected in the home.';

      case 'gas':
        return 'Possible gas leakage detected.';

      case 'smoke':
        return 'Smoke detected in the home.';

      default:
        return 'A safety hazard has been detected.';
    }
  }

  IconData hazardIcon(String hazard) {
    switch (hazard.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department_rounded;

      case 'gas':
        return Icons.air_rounded;

      case 'smoke':
        return Icons.cloud_rounded;

      default:
        return Icons.warning_rounded;
    }
  }

  // ==========================================================
  // HANDLE EMERGENCY
  // ==========================================================

  Future<void> handleEmergency(
    Map<String, dynamic> data,
  ) async {
    final String status =
        data['status']
                ?.toString()
                .toLowerCase() ??
            '';

    final bool emergency =
        data['emergency'] == true ||
        status == 'emergency';

    // New emergency
    if (emergency &&
        !previousEmergency) {
      await showCaretakerNotification(
        title:
            '🚨 HOME CARE EMERGENCY',
        message:
            'The elderly person needs immediate assistance.',
      );
    }

    // Emergency cleared
    if (!emergency &&
        previousEmergency) {
      await stopCaretakerAlert();
    }

    previousEmergency = emergency;
  }

  // ==========================================================
  // HANDLE HAZARD
  // ==========================================================

  Future<void> handleHazard(
    Map<String, dynamic> data,
  ) async {
    final bool active =
        data['active'] == true;

    final String hazard =
        data['hazard']
                ?.toString()
                .toLowerCase() ??
            '';

    final String message =
        data['message']
                ?.toString() ??
            hazardSubtitle(hazard);

    final bool newHazard =
        active &&
        (!previousHazard ||
            previousHazardType != hazard);

    if (newHazard) {
      await showCaretakerNotification(
        title: '🚨 ${hazardTitle(hazard)}',
        message: message,
      );
    }

    if (!active &&
        previousHazard) {
      await stopCaretakerAlert();
    }

    previousHazard = active;
    previousHazardType = hazard;
  }

  // ==========================================================
  // HANDLE CARETAKER RESPONSE
  // ==========================================================

  Future<void> handleCareResponse(
    Map<String, dynamic> data,
  ) async {
    final String requestStatus =
        data['status']
                ?.toString() ??
            '';

    final String response =
        data['response']
                ?.toString()
                .toLowerCase() ??
            '';

    if (requestStatus == 'answered' &&
        response.isNotEmpty &&
        response != previousResponse) {

      if (response == 'help') {
        await showCaretakerNotification(
          title:
              '🔴 ELDERLY NEEDS HELP',
          message:
              'The elderly person has requested assistance.',
        );
      } else if (response == 'okay') {
        await stopCaretakerAlert();

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'The elderly person is okay.',
                style:
                    TextStyle(fontSize: 16),
              ),
              backgroundColor:
                  Colors.green,
              behavior:
                  SnackBarBehavior.floating,
            ),
          );
        }
      }

      previousResponse = response;
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      body: SafeArea(
        child: StreamBuilder<
            DocumentSnapshot<
                Map<String, dynamic>>>(
          stream:
              elderlyReference.snapshots(),

          builder:
              (context, elderlySnapshot) {

            final Map<String, dynamic>
                elderlyData =
                elderlySnapshot.data
                        ?.data() ??
                    {};

            // Trigger emergency notification.
            handleEmergency(
              elderlyData,
            );

            return StreamBuilder<
                DocumentSnapshot<
                    Map<String, dynamic>>>(
              stream:
                  hazardReference.snapshots(),

              builder:
                  (context, hazardSnapshot) {

                final Map<String, dynamic>
                    hazardData =
                    hazardSnapshot.data
                            ?.data() ??
                        {};

                // Trigger hazard notification.
                handleHazard(
                  hazardData,
                );

                return StreamBuilder<
                    DocumentSnapshot<
                        Map<String, dynamic>>>(
                  stream:
                      careRequestReference
                          .snapshots(),

                  builder: (
                    context,
                    requestSnapshot,
                  ) {
                    final Map<String, dynamic>
                        requestData =
                        requestSnapshot.data
                                ?.data() ??
                            {};

                    // Trigger help notification.
                    handleCareResponse(
                      requestData,
                    );

                    return _buildPage(
                      elderlyData,
                      hazardData,
                      requestData,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==========================================================
  // MAIN PAGE
  // ==========================================================

  Widget _buildPage(
    Map<String, dynamic> elderlyData,
    Map<String, dynamic> hazardData,
    Map<String, dynamic> requestData,
  ) {
    final String elderlyStatus =
        elderlyData['status']
                ?.toString()
                .toLowerCase() ??
            'okay';

    final bool elderlyEmergency =
        elderlyData['emergency'] == true ||
        elderlyStatus == 'emergency';

    final String elderlyMessage =
        elderlyData['message']
                ?.toString() ??
            'I am okay';

    final bool hazardActive =
        hazardData['active'] == true;

    final String hazard =
        hazardData['hazard']
                ?.toString() ??
            '';

    final String hazardMessage =
        hazardData['message']
                ?.toString() ??
            hazardSubtitle(hazard);

    final String hazardSeverity =
        hazardData['severity']
                ?.toString() ??
            'critical';

    final String requestStatus =
        requestData['status']
                ?.toString() ??
            'idle';

    final String response =
        requestData['response']
                ?.toString() ??
            '';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },

      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          20,
          18,
          20,
          30,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            _buildHeader(),

            const SizedBox(height: 28),

            _buildMainStatusCard(
              elderlyEmergency:
                  elderlyEmergency,
              hazardActive:
                  hazardActive,
              hazard: hazard,
              elderlyMessage:
                  elderlyMessage,
              hazardMessage:
                  hazardMessage,
            ),

            if (hazardActive) ...[
              const SizedBox(height: 20),

              _buildHazardCard(
                hazard: hazard,
                message: hazardMessage,
                severity: hazardSeverity,
              ),
            ],

            if (elderlyEmergency &&
                !hazardActive) ...[
              const SizedBox(height: 20),

              _buildEmergencyCard(
                message: elderlyMessage,
              ),
            ],

            const SizedBox(height: 20),

            _buildCheckInSection(
              requestStatus:
                  requestStatus,
              response: response,
            ),

            const SizedBox(height: 20),

            _buildConnectionCard(),

            const SizedBox(height: 25),

            Center(
              child: Text(
                'Home Care • Elderly Safety System',
                style: TextStyle(
                  color:
                      Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,

          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius:
                BorderRadius.circular(18),
          ),

          child: const Icon(
            Icons.health_and_safety_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(width: 14),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'HOME CARE',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              SizedBox(height: 2),

              Text(
                'Caretaker Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),

          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius:
                BorderRadius.circular(20),
          ),

          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,

                decoration:
                    const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                'LIVE',
                style: TextStyle(
                  color:
                      Colors.green.shade700,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // MAIN STATUS CARD
  // ==========================================================

  Widget _buildMainStatusCard({
    required bool elderlyEmergency,
    required bool hazardActive,
    required String hazard,
    required String elderlyMessage,
    required String hazardMessage,
  }) {
    // --------------------------------------------------------
    // HAZARD
    // --------------------------------------------------------

    if (hazardActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),

        decoration: BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,

            colors: [
              Colors.red.shade700,
              Colors.red.shade500,
            ],
          ),

          borderRadius:
              BorderRadius.circular(28),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.red.withOpacity(
                0.25,
              ),
              blurRadius: 18,
              offset:
                  const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          children: [
            const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 68,
            ),

            const SizedBox(height: 12),

            const Text(
              'HOME HAZARD',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              hazardTitle(hazard),
              textAlign:
                  TextAlign.center,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              hazardMessage,
              textAlign:
                  TextAlign.center,

              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // --------------------------------------------------------
    // ELDERLY EMERGENCY
    // --------------------------------------------------------

    if (elderlyEmergency) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),

        decoration: BoxDecoration(
          color: Colors.red.shade50,

          borderRadius:
              BorderRadius.circular(28),

          border: Border.all(
            color: Colors.red.shade300,
            width: 2,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.red.withOpacity(
                0.12,
              ),
              blurRadius: 15,
              offset:
                  const Offset(0, 6),
            ),
          ],
        ),

        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,

              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.red,
                size: 46,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'EMERGENCY',
              style: TextStyle(
                color: Colors.red,
                fontSize: 31,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'The elderly person needs assistance.',
              textAlign:
                  TextAlign.center,

              style: TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              elderlyMessage,
              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color:
                    Colors.red.shade800,
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // --------------------------------------------------------
    // EVERYTHING OKAY
    // --------------------------------------------------------

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,

          colors: [
            Colors.green.shade600,
            Colors.green.shade500,
          ],
        ),

        borderRadius:
            BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color:
                Colors.green.withOpacity(
              0.20,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,

            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(
                0.18,
              ),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'EVERYTHING IS OKAY',
            textAlign:
                TextAlign.center,

            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'The elderly person is safe.',
            textAlign:
                TextAlign.center,

            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HAZARD CARD
  // ==========================================================

  Widget _buildHazardCard({
    required String hazard,
    required String message,
    required String severity,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        border: Border.all(
          color: Colors.red.shade200,
          width: 2,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,

                decoration: BoxDecoration(
                  color:
                      Colors.red.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),

                child: Icon(
                  hazardIcon(hazard),
                  color: Colors.red,
                  size: 30,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'ACTIVE HAZARD',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      'Immediate attention required',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color:
                      Colors.red.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child: Text(
                  severity.toUpperCase(),
                  style:
                      const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            hazardTitle(hazard),
            style: const TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            message,
            style: TextStyle(
              color:
                  Colors.grey.shade700,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EMERGENCY CARD
  // ==========================================================

  Widget _buildEmergencyCard({
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.red.shade50,

        borderRadius:
            BorderRadius.circular(24),

        border: Border.all(
          color: Colors.red.shade200,
          width: 2,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.red,
              size: 31,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'EMERGENCY ALERT',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CHECK ON ELDERLY
  // ==========================================================

  Widget _buildCheckInSection({
    required String requestStatus,
    required String response,
  }) {
    final bool pending =
        requestStatus == 'pending';

    final bool answered =
        requestStatus == 'answered' &&
        response.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(24),

        border: Border.all(
          color: Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color:
                      Colors.blue.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: Icon(
                  Icons.person_search_rounded,
                  color:
                      Colors.blue.shade700,
                  size: 28,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'CHECK ON ELDERLY',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      'Need to check if they are okay?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 64,

            child: ElevatedButton(
              onPressed:
                  pending || asking
                      ? null
                      : askAreYouOkay,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.blue.shade700,
                foregroundColor:
                    Colors.white,

                disabledBackgroundColor:
                    Colors.grey.shade300,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),

                elevation: 2,
              ),

              child: pending
                  ? const Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color:
                                Colors.white,
                          ),
                        ),

                        SizedBox(width: 12),

                        Text(
                          'WAITING FOR RESPONSE...',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'ARE YOU OKAY?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
            ),
          ),

          if (answered) ...[
            const SizedBox(height: 18),

            _buildResponseCard(
              response,
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // RESPONSE
  // ==========================================================

  Widget _buildResponseCard(
    String response,
  ) {
    final bool okay =
        response.toLowerCase() ==
            'okay';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: okay
            ? Colors.green.shade50
            : Colors.red.shade50,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: okay
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: okay
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              shape: BoxShape.circle,
            ),

            child: Icon(
              okay
                  ? Icons.check_rounded
                  : Icons.priority_high_rounded,

              color: okay
                  ? Colors.green.shade700
                  : Colors.red.shade700,

              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'ELDERLY RESPONSE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 0.8,
                    color: okay
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  okay
                      ? 'I\'M OKAY'
                      : 'I NEED HELP',

                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w900,
                    color: okay
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CONNECTION
  // ==========================================================

  Widget _buildConnectionCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Icon(
              Icons.cloud_done_rounded,
              color:
                  Colors.green.shade700,
              size: 25,
            ),
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
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  'Real-time monitoring active',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Text(
              'CONNECTED',
              style: TextStyle(
                color:
                    Colors.green.shade700,
                fontSize: 10,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}