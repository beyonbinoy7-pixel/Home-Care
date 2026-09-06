import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const HomeCareSimulator());
}

class HomeCareSimulator extends StatelessWidget {
  const HomeCareSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Care Simulator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        fontFamily: 'Arial',
      ),
      home: const SimulatorHome(),
    );
  }
}

class SimulatorHome extends StatefulWidget {
  const SimulatorHome({super.key});

  @override
  State<SimulatorHome> createState() => _SimulatorHomeState();
}

class _SimulatorHomeState extends State<SimulatorHome> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static const String hazardPath = 'hazards/home_001';
  static const String elderlyPath = 'elderly_users/elderly_001';
  static const String checkInPath = 'care_requests/elderly_001';

  String currentStatus = 'EVERYTHING IS OKAY';
  String currentMessage = 'No hazards are currently active.';
  String currentIcon = '🟢';

  bool lightsOn = false;
  bool movementDetected = true;
  bool fallDetected = false;
  bool checkInWaiting = false;
  bool firebaseConnected = true;

  int inactivitySeconds = 0;

  Timer? inactivityTimer;

  final List<String> eventLog = [];

  @override
  void dispose() {
    inactivityTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // FIREBASE
  // ============================================================

  Future<void> writeHazard({
    required String hazard,
    required String severity,
    required String message,
  }) async {
    try {
      await firestore.doc(hazardPath).set({
        'hazard': hazard,
        'active': true,
        'severity': severity,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        firebaseConnected = true;
      });
    } catch (e) {
      setState(() {
        firebaseConnected = false;
      });

      addLog('❌ FIREBASE ERROR');
    }
  }

  Future<void> clearHazard() async {
    try {
      await firestore.doc(hazardPath).set({
        'hazard': '',
        'active': false,
        'severity': 'normal',
        'message': 'No active hazards',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        firebaseConnected = true;
      });
    } catch (e) {
      setState(() {
        firebaseConnected = false;
      });

      addLog('❌ FIREBASE ERROR WHILE CLEARING');
    }
  }

  Future<void> writeElderlyEmergency({
    required bool emergency,
    required String status,
    required String message,
  }) async {
    try {
      await firestore.doc(elderlyPath).set({
        'status': status,
        'message': message,
        'emergency': emergency,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        firebaseConnected = true;
      });
    } catch (e) {
      setState(() {
        firebaseConnected = false;
      });

      addLog('❌ FIREBASE ERROR');
    }
  }

  Future<void> writeCheckInRequest() async {
    try {
      await firestore.doc(checkInPath).set({
        'status': 'pending',
        'response': '',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        firebaseConnected = true;
      });
    } catch (e) {
      setState(() {
        firebaseConnected = false;
      });

      addLog('❌ FIREBASE CHECK-IN ERROR');
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  void addLog(String message) {
    final time = TimeOfDay.now().format(context);

    setState(() {
      eventLog.insert(0, '$time  •  $message');
    });
  }

  void updateStatus({
    required String icon,
    required String title,
    required String message,
  }) {
    setState(() {
      currentIcon = icon;
      currentStatus = title;
      currentMessage = message;
    });
  }

  // ============================================================
  // FIRE
  // ============================================================

  Future<void> simulateFire() async {
    updateStatus(
      icon: '🔥',
      title: 'FIRE DETECTED',
      message: 'Flame sensor has detected a possible fire.',
    );

    addLog('🔥 FIRE DETECTED');

    await writeHazard(
      hazard: 'fire',
      severity: 'critical',
      message: 'Flame sensor has detected a possible fire.',
    );
  }

  // ============================================================
  // GAS
  // ============================================================

  Future<void> simulateGas() async {
    updateStatus(
      icon: '💨',
      title: 'GAS LEAK DETECTED',
      message: 'Gas sensor level has exceeded the safety threshold.',
    );

    addLog('💨 GAS LEAK DETECTED');

    await writeHazard(
      hazard: 'gas',
      severity: 'critical',
      message: 'Gas sensor level has exceeded the safety threshold.',
    );
  }

  // ============================================================
  // EARTHQUAKE
  // ============================================================

  Future<void> simulateEarthquake() async {
    updateStatus(
      icon: '🌎',
      title: 'ABNORMAL VIBRATION',
      message: 'Vibration sensor detected unusual ground movement.',
    );

    addLog('🌎 ABNORMAL VIBRATION DETECTED');

    await writeHazard(
      hazard: 'earthquake',
      severity: 'critical',
      message: 'Abnormal ground vibration detected.',
    );
  }

  // ============================================================
  // LANDSLIDE
  // ============================================================

  Future<void> simulateLandslide() async {
    updateStatus(
      icon: '⛰️',
      title: 'LANDSLIDE RISK',
      message: 'Tilt and vibration conditions indicate possible movement.',
    );

    addLog('⛰️ LANDSLIDE RISK DETECTED');

    await writeHazard(
      hazard: 'landslide',
      severity: 'critical',
      message: 'Tilt and vibration conditions indicate possible movement.',
    );
  }

  // ============================================================
  // BREAK-IN
  // ============================================================

  Future<void> simulateBreakIn() async {
    setState(() {
      lightsOn = true;
    });

    updateStatus(
      icon: '🚨',
      title: 'INTRUSION DETECTED',
      message:
          'Unexpected movement detected. Automatic lights activated.',
    );

    addLog('🚨 INTRUSION DETECTED');
    addLog('💡 AUTOMATIC LIGHTS TURNED ON');

    await writeHazard(
      hazard: 'break_in',
      severity: 'critical',
      message:
          'Unexpected movement detected. Automatic lights activated.',
    );
  }

  // ============================================================
  // ELDERLY EMERGENCY
  // ============================================================

  Future<void> simulateEmergency() async {
    updateStatus(
      icon: '🆘',
      title: 'ELDERLY EMERGENCY',
      message: 'Emergency assistance has been requested.',
    );

    addLog('🆘 ELDERLY EMERGENCY');

    await writeElderlyEmergency(
      emergency: true,
      status: 'emergency',
      message: 'Emergency assistance has been requested.',
    );

    await writeHazard(
      hazard: 'emergency',
      severity: 'critical',
      message: 'Emergency assistance has been requested.',
    );
  }

  // ============================================================
  // FALL
  // ============================================================

  Future<void> simulateFall() async {
    setState(() {
      fallDetected = true;
      movementDetected = false;
    });

    updateStatus(
      icon: '🧓',
      title: 'FALL DETECTED',
      message:
          'Possible fall detected. Elderly person may need assistance.',
    );

    addLog('🧓 POSSIBLE FALL DETECTED');

    await writeHazard(
      hazard: 'fall',
      severity: 'critical',
      message:
          'Possible fall detected. Elderly person may need assistance.',
    );
  }

  // ============================================================
  // NO MOVEMENT
  // ============================================================

  void startNoMovementSimulation() {
    inactivityTimer?.cancel();

    setState(() {
      movementDetected = false;
      inactivitySeconds = 0;
      currentIcon = '🛑';
      currentStatus = 'MONITORING NO MOVEMENT';
      currentMessage =
          'Movement has stopped. Monitoring inactivity...';
    });

    addLog('🛑 MOVEMENT STOPPED');

    inactivityTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) return;

        setState(() {
          inactivitySeconds++;
        });

        if (inactivitySeconds >= 10) {
          timer.cancel();

          updateStatus(
            icon: '🆘',
            title: 'PROLONGED INACTIVITY',
            message:
                'No movement detected for 10 seconds. Elderly person may need assistance.',
          );

          addLog('🆘 NO MOVEMENT ALERT TRIGGERED');

          writeHazard(
            hazard: 'fall',
            severity: 'critical',
            message:
                'No movement detected for 10 seconds. Elderly person may need assistance.',
          );
        }
      },
    );
  }

  void restoreMovement() {
    inactivityTimer?.cancel();

    setState(() {
      movementDetected = true;
      inactivitySeconds = 0;
      fallDetected = false;
    });

    addLog('🟢 MOVEMENT RESTORED');
  }

  // ============================================================
  // LIGHTS
  // ============================================================

  void toggleLights() {
    setState(() {
      lightsOn = !lightsOn;
    });

    addLog(
      lightsOn
          ? '💡 LIGHTS MANUALLY TURNED ON'
          : '🌙 LIGHTS MANUALLY TURNED OFF',
    );
  }

  // ============================================================
  // CARETAKER CHECK-IN
  // ============================================================

  Future<void> sendCheckIn() async {
    setState(() {
      checkInWaiting = true;
    });

    addLog('👨‍⚕️ CARETAKER ASKED: ARE YOU OKAY?');

    await writeCheckInRequest();
  }

  Future<void> elderlyOkay() async {
    setState(() {
      checkInWaiting = false;
    });

    addLog('🟢 ELDERLY RESPONSE: I AM OKAY');

    await firestore.doc(checkInPath).set({
      'status': 'answered',
      'response': 'okay',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> elderlyNeedsHelp() async {
    setState(() {
      checkInWaiting = false;
    });

    updateStatus(
      icon: '🆘',
      title: 'ELDERLY NEEDS HELP',
      message:
          'The elderly person responded that they need assistance.',
    );

    addLog('🔴 ELDERLY RESPONSE: I NEED HELP');

    await firestore.doc(checkInPath).set({
      'status': 'answered',
      'response': 'help',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    await writeElderlyEmergency(
      emergency: true,
      status: 'emergency',
      message: 'The elderly person requested help.',
    );

    await writeHazard(
      hazard: 'emergency',
      severity: 'critical',
      message: 'The elderly person requested help.',
    );
  }

  // ============================================================
  // CLEAR EVERYTHING
  // ============================================================

  Future<void> clearAll() async {
    inactivityTimer?.cancel();

    setState(() {
      currentIcon = '🟢';
      currentStatus = 'EVERYTHING IS OKAY';
      currentMessage = 'No hazards are currently active.';

      lightsOn = false;
      movementDetected = true;
      fallDetected = false;
      checkInWaiting = false;
      inactivitySeconds = 0;
    });

    addLog('🟢 ALL HAZARDS CLEARED');

    await clearHazard();

    await writeElderlyEmergency(
      emergency: false,
      status: 'okay',
      message: 'System cleared.',
    );

    try {
      await firestore.doc(checkInPath).set({
        'status': 'cleared',
        'response': '',
        'clearedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget buildHazardButton({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 120,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool danger =
        currentStatus != 'EVERYTHING IS OKAY';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1100,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            '🏠',
                            style: TextStyle(fontSize: 26),
                          ),
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
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'Elderly Safety Simulation Console',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'SIMULATION MODE',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // FIREBASE STATUS
                  // ==================================================

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: firebaseConnected
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: firebaseConnected
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          firebaseConnected
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: firebaseConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          firebaseConnected
                              ? 'FIREBASE CONNECTED'
                              : 'FIREBASE CONNECTION ERROR',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: firebaseConnected
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // STATUS
                  // ==================================================

                  AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: danger
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(24),
                      border: Border.all(
                        color: danger
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          currentIcon,
                          style:
                              const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentStatus,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: danger
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                currentMessage,
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // SAFETY
                  // ==================================================

                  buildSectionTitle(
                    'Safety Simulations',
                    'Trigger situations normally detected by the physical sensors.',
                  ),

                  const SizedBox(height: 14),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth > 750
                              ? 3
                              : constraints.maxWidth > 480
                                  ? 2
                                  : 1;

                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.0,
                        children: [
                          buildHazardButton(
                            icon: '🔥',
                            title: 'FIRE',
                            subtitle:
                                'Simulate flame detection',
                            onPressed: simulateFire,
                          ),
                          buildHazardButton(
                            icon: '💨',
                            title: 'GAS LEAK',
                            subtitle:
                                'Simulate gas threshold',
                            onPressed: simulateGas,
                          ),
                          buildHazardButton(
                            icon: '🌎',
                            title: 'EARTHQUAKE',
                            subtitle:
                                'Simulate abnormal vibration',
                            onPressed:
                                simulateEarthquake,
                          ),
                          buildHazardButton(
                            icon: '⛰️',
                            title: 'LANDSLIDE',
                            subtitle:
                                'Simulate tilt + vibration',
                            onPressed:
                                simulateLandslide,
                          ),
                          buildHazardButton(
                            icon: '🚨',
                            title: 'BREAK-IN',
                            subtitle:
                                'Intrusion + auto lights',
                            onPressed:
                                simulateBreakIn,
                          ),
                          buildHazardButton(
                            icon: '🆘',
                            title: 'EMERGENCY',
                            subtitle:
                                'Simulate emergency button',
                            onPressed:
                                simulateEmergency,
                          ),
                          buildHazardButton(
                            icon: '🧓',
                            title: 'FALL DETECTED',
                            subtitle:
                                'Simulate elderly fall',
                            onPressed: simulateFall,
                          ),
                          buildHazardButton(
                            icon: '🛑',
                            title: 'NO MOVEMENT',
                            subtitle:
                                '10-second inactivity test',
                            onPressed:
                                startNoMovementSimulation,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // LIGHTS
                  // ==================================================

                  buildSectionTitle(
                    'Automatic Lighting',
                    'Intrusion automatically activates the lights.',
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          lightsOn ? '💡' : '🌙',
                          style:
                              const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                lightsOn
                                    ? 'LIGHTS ON'
                                    : 'LIGHTS OFF',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lightsOn
                                    ? 'Lighting has been activated.'
                                    : 'No automatic lighting currently active.',
                                style: TextStyle(
                                  color:
                                      Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: lightsOn,
                          onChanged: (_) =>
                              toggleLights(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // MOVEMENT
                  // ==================================================

                  buildSectionTitle(
                    'Elderly Movement Monitor',
                    'Prototype simulation for fall and prolonged inactivity.',
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              movementDetected
                                  ? '🟢'
                                  : '🔴',
                              style:
                                  const TextStyle(
                                      fontSize: 32),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movementDetected
                                        ? 'MOVEMENT DETECTED'
                                        : 'NO MOVEMENT',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    inactivitySeconds > 0
                                        ? 'Inactive for $inactivitySeconds seconds'
                                        : 'Elderly person is active.',
                                    style: TextStyle(
                                      color: Colors
                                          .grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed:
                                  restoreMovement,
                              child:
                                  const Text('RESTORE'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed: simulateFall,
                                icon: const Text('🧓'),
                                label: const Text(
                                  'SIMULATE FALL',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed:
                                    startNoMovementSimulation,
                                icon: const Text('🛑'),
                                label: const Text(
                                  'STOP MOVEMENT',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // CHECK-IN
                  // ==================================================

                  buildSectionTitle(
                    'Caretaker Check-in',
                    'Simulate communication between caretaker and elderly person.',
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              '👨‍⚕️',
                              style:
                                  TextStyle(fontSize: 34),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Ask the elderly person: Are you okay?',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: sendCheckIn,
                              child:
                                  const Text('ASK'),
                            ),
                          ],
                        ),
                        if (checkInWaiting) ...[
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'WAITING FOR ELDERLY RESPONSE...',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      elderlyOkay,
                                  style:
                                      FilledButton.styleFrom(
                                    backgroundColor:
                                        Colors.green,
                                  ),
                                  child: const Text(
                                    '🟢 I AM OKAY',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      elderlyNeedsHelp,
                                  style:
                                      FilledButton.styleFrom(
                                    backgroundColor:
                                        Colors.red,
                                  ),
                                  child: const Text(
                                    '🔴 I NEED HELP',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // EVENT LOG
                  // ==================================================

                  Row(
                    children: [
                      buildSectionTitle(
                        'Event Log',
                        'Recent simulator activity.',
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            eventLog.clear();
                          });
                        },
                        child:
                            const Text('CLEAR LOG'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(
                      minHeight: 130,
                    ),
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: eventLog.isEmpty
                        ? Center(
                            child: Text(
                              'No events yet.',
                              style: TextStyle(
                                color:
                                    Colors.grey.shade500,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: eventLog
                                .take(12)
                                .map((event) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(
                                  bottom: 10,
                                ),
                                child: Text(
                                  event,
                                  style:
                                      const TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // RESET
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: clearAll,
                      icon:
                          const Icon(Icons.refresh),
                      label: const Text(
                        'CLEAR ALL HAZARDS & RESET SYSTEM',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}