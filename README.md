🏠 Home Care --- Elderly Safety & Home Monitoring System

An IoT-based elderly safety and home monitoring prototype connecting
sensors, a Wemos D1 R1 (ESP8266), Firebase Firestore, an elderly
mobile app, a caretaker mobile app, and a Flutter simulator.

📌 Overview

Home Care is designed to help monitor elderly people at home and
alert a caretaker when important safety events occur.

The current prototype supports:

🔥 Fire detection

💨 Gas-leak detection

🚨 Intrusion/break-in detection

🆘 Elderly emergency detection

📏 Ultrasonic person/distance detection

💡 Automatic lighting using LDR + relay

👨‍⚕️ Caretaker check-in

🔔 Mobile notifications and vibration

🖥️ Hardware simulation through Flutter

☁️ Firebase Firestore communication

Tilt and vibration based detection are planned for a later version.

🎯 Problem Statement

Elderly people living alone can face emergencies such as fire, gas
leakage, intrusion, or situations where they need immediate assistance.
A simple and affordable monitoring system can help detect these events
and communicate them to a caretaker.

Home Care combines low-cost IoT hardware with cloud-connected mobile
applications to provide a prototype solution.

💡 Proposed Solution

Sensors
   ↓
Wemos D1 R1 / ESP8266
   ↓ USB Serial
Python Firebase Bridge
   ↓
Firebase Firestore
   ↓
┌──────────────────┐
│                  │
▼                  ▼
Elderly App    Caretaker App
│                  │
🔔 Alert           🔔 Alert

The elderly application provides simple controls such as I AM OKAY
and EMERGENCY. The caretaker application monitors the elderly user's
status and active hazards.

🏗️ System Architecture

┌─────────────────────────────┐
│          SENSORS            │
│ Flame | Gas | IR | Touch    │
│ Ultrasonic | LDR            │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│      WEMOS D1 R1            │
│        ESP8266              │
└──────────────┬──────────────┘
               │ USB Serial
               ▼
┌─────────────────────────────┐
│     Python Bridge           │
│     Laptop Application      │
└──────────────┬──────────────┘
               │ Internet
               ▼
┌─────────────────────────────┐
│     Firebase Firestore      │
└──────────────┬──────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌─────────────┐  ┌──────────────┐
│ Elderly App │  │ Caretaker App│
└─────────────┘  └──────────────┘

📁 Repository Structure

Home-Care/
│
├── elderly_app/
│   ├── lib/
│   ├── android/
│   ├── pubspec.yaml
│   └── ...
│
├── caretaker_app/
│   ├── lib/
│   ├── android/
│   ├── pubspec.yaml
│   └── ...
│
├── home_care_simulator/
│   ├── lib/
│   ├── web/
│   ├── windows/
│   └── ...
│
├── home_care_bridge/
│   └── bridge.py
│
├── .gitignore
└── README.md

🔧 Hardware

Controller

Wemos D1 R1 / ESP8266

Current Hardware

Component               Purpose                Pin

🔥 Flame sensor         Fire detection         D2
🚨 IR sensor            Intrusion detection    D3
🆘 Touch sensor         Emergency input        D4
📏 Ultrasonic Echo      Distance measurement   D7
📏 Ultrasonic Trig      Trigger                D8
☀️ LDR digital output   Light/dark detection   D9
🔌 Relay                Automatic light        D10
💨 Gas sensor AO        Gas level              A0

Planned

Tilt sensor

Vibration sensor

🚨 Detection Logic

🔥 Fire

Flame sensor
     ↓
Wemos
     ↓
EVENT=FIRE
     ↓
Firebase
     ↓
Mobile alerts

💨 Gas Leak

The gas sensor provides an analog value through A0.

Current prototype threshold:

GAS_THRESHOLD = 600

This threshold should be calibrated for the actual sensor/module.

🚨 Break-In

The IR sensor detects an object/person according to its configured
active state and generates:

EVENT=BREAK_IN

🆘 Elderly Emergency

The touch sensor can generate:

EVENT=ELDERLY_EMERGENCY

The elderly mobile app also has an emergency button.

📏 Person Detection

The ultrasonic sensor measures distance. The current prototype treats a
distance below 200 cm as person detection.

💡 Automatic Lighting

The intended behavior is:

Person / intrusion detected
          +
Dark environment
          ↓
       Relay ON
          ↓
       Light ON
          ↓
       30 seconds
          ↓
       Relay OFF

The LDR module may require threshold/potentiometer calibration.

☁️ Firebase

Firebase project:

home-care-9a355

Main Firestore paths:

hazards/home_001
elderly_users/elderly_001
caretaker_users/caretaker_001
care_requests/elderly_001

Example hazard document:

{
  "hazard": "fire",
  "active": true,
  "severity": "critical",
  "message": "Fire detected by flame sensor",
  "timestamp": "timestamp"
}

🖥️ Wemos → Firebase Bridge

The current prototype uses a laptop as the bridge between the Wemos USB
serial connection and Firebase.

Wemos
  ↓ USB
Laptop
  ↓ Python
Firebase

This avoids placing Firebase Admin credentials inside the Wemos.

Install dependencies

py -m pip install pyserial requests

Configure the Firebase API key

The bridge reads the key from the Windows environment variable:

HOME_CARE_FIREBASE_API_KEY

The key is intentionally not stored directly in bridge.py.

Run

cd home_care_bridge
py bridge.py

Example:

HOME CARE FIREBASE BRIDGE

Serial Port : COM10
Baud Rate   : 115200
Firebase    : home-care-9a355

Firebase API key: FOUND

WEMOS CONNECTED

Close Arduino IDE's Serial Monitor before starting the bridge because
only one application should use the COM port at a time.

📡 Serial Protocol

The Wemos outputs simple key/value data:

FLAME=1
IR=1
TOUCH=0
GAS=123
LDR=1
DISTANCE=48.8cm
FIRE=0
GAS_ALERT=0
INTRUSION=0
EMERGENCY=0
DARK=0
PERSON=1
LIGHT=0
EVENT=NORMAL

Current event messages:

EVENT=FIRE
EVENT=GAS_LEAK
EVENT=BREAK_IN
EVENT=ELDERLY_EMERGENCY
EVENT=NORMAL

📱 Elderly App

The elderly application is designed for simple interaction.

Main Features

🟢 I AM OKAY

Allows the elderly user to confirm that they are safe.

🔴 EMERGENCY

Allows the elderly user to request immediate assistance.

👨‍⚕️ Caretaker Check-In

The caretaker can ask:

Are you okay?

The elderly user can respond:

🟢 I'M OKAY
🔴 I NEED HELP

The response is stored in Firestore.

🔔 Notifications

The application supports Firebase Cloud Messaging, local notifications,
and vibration.

📱 Caretaker App

The caretaker application monitors the elderly user and hazards.

Features include:

🟢 Elderly safe status

🔴 Emergency status

🔥 Fire alerts

💨 Gas alerts

🚨 Break-in alerts

🆘 Elderly emergency alerts

👨‍⚕️ Check-in requests

🔔 Notifications

📳 Vibration alerts

🖥️ Flutter Simulator

The simulator allows the software system to be tested without physically
triggering sensors.

It can simulate events including:

Fire

Gas

Earthquake prototype event

Landslide prototype event

Break-in

Emergency

Fall

No movement

Caretaker check-in

The simulator communicates with the same Firebase project used by the
mobile applications.

🧪 Tested Pipeline

The real hardware pipeline has been tested:

Physical Sensor
      ↓
Wemos D1 R1
      ↓
USB Serial
      ↓
Python Bridge
      ↓
Firebase Firestore
      ↓
Elderly App
      ↓
Caretaker App

The Flutter simulator has also been used to test Firebase-to-application
behavior.

🚨 Event Priority

The intended priority is:

🆘 Elderly Emergency
        ↓
🔥 Fire / 💨 Gas
        ↓
🌎 Earthquake
        ↓
⛰️ Landslide
        ↓
🚨 Break-in

The current physical hardware directly supports:

🔥 Fire
💨 Gas Leak
🚨 Break-in
🆘 Elderly Emergency

Earthquake and landslide detection are planned extensions.

🌎 Future Detection

Tilt and vibration sensors are planned for future versions.

Prototype concepts:

Abnormal vibration
        ↓
Earthquake / abnormal ground vibration

and:

Tilt + sustained vibration
        ↓
Landslide risk

These are prototype concepts and are not intended to replace
professional earthquake or geotechnical warning systems.

🛠️ Technology Stack

Mobile

Flutter

Dart

Firebase Core

Cloud Firestore

Firebase Cloud Messaging

Flutter Local Notifications

Vibration

Simulator

Flutter

Dart

Firebase Core

Cloud Firestore

Hardware

Wemos D1 R1

ESP8266

Flame sensor

Gas sensor

IR sensor

Touch sensor

Ultrasonic sensor

LDR module

Relay module

Bridge

Python

PySerial

Requests

Firestore REST API

🚀 Getting Started

Clone

git clone https://github.com/beyonbinoy7-pixel/Home-Care.git
cd Home-Care

Elderly App

cd elderly_app
flutter pub get
flutter run

Caretaker App

cd caretaker_app
flutter pub get
flutter run

Simulator

cd home_care_simulator
flutter pub get
flutter run -d chrome

Bridge

cd home_care_bridge
py -m pip install pyserial requests
py bridge.py

Make sure the configured COM port matches the Wemos.

🔐 Security

Do not commit:

.env
serviceAccountKey.json
google-services-admin.json

The bridge Firebase API key is stored outside the source code using:

HOME_CARE_FIREBASE_API_KEY

Never publish Firebase Admin private keys, passwords, tokens, or
service-account credentials.

The repository contains a .gitignore for common local secrets and
generated files.

⚠️ Hardware Safety

The ESP8266 uses 3.3 V logic.

Before connecting modules:

Verify sensor output voltage levels.

A typical ultrasonic ECHO output may require level shifting before
entering an ESP8266 GPIO.

Verify the gas module's analog output is safe for the board's analog
input.

Relay modules may be active-low or active-high.

Flame, IR, touch, and LDR module polarity can vary.

Do not use real dangerous gas or uncontrolled fire for testing.

💰 Firebase Cost

The current prototype is designed around the Firebase Spark/no-payment
setup.

The current architecture is:

Wemos
  ↓
Laptop bridge
  ↓
Firestore
  ↓
Mobile applications

A production system may require additional backend infrastructure for
advanced server-side notification workflows.

🗺️ Roadmap

Phase 1 --- Completed

Elderly application

Caretaker application

Firebase integration

Flame sensor

Gas sensor

IR sensor

Ultrasonic sensor

Touch/emergency sensor

Relay

Fire hazard

Gas hazard

Break-in prototype

Elderly emergency

Caretaker check-in

Local notifications

Vibration alerts

Flutter simulator

Python Wemos/Firebase bridge

Real hardware → Firebase testing

GitHub repository

Phase 2 --- Planned

Improve LDR calibration

Add tilt sensor

Add vibration sensor

Improve earthquake prototype detection

Improve landslide-risk prototype

Sensor filtering/debouncing

Hardware enclosure

System health monitoring

Production deployment improvements

👥 Project

Home Care

IoT + Flutter + Firebase + Mobile Alerts

A prototype elderly safety and home monitoring system designed to
connect real-world sensors with cloud-connected mobile applications.

⭐ Project Flow

🔥 Fire
💨 Gas
🚨 Intrusion
🆘 Emergency
📏 Person Detection
        │
        ▼
   Wemos D1 R1
        │
        ▼
   USB Serial
        │
        ▼
 Python Bridge
        │
        ▼
 Firebase
      /        /         ▼       ▼
Elderly   Caretaker
  App       App
   🔔        🔔

Home Care --- connecting hardware, cloud, and people for safer elderly
living.

demo video: https://youtu.be/N1IuNtcQ_Uw
