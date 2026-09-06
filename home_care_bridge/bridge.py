import os
import serial
import requests
from datetime import datetime, timezone


# ============================================================
# HOME CARE - WEMOS → FIREBASE BRIDGE
# GitHub-safe version
# ============================================================

# ------------------------------------------------------------
# WEMOS SERIAL SETTINGS
# ------------------------------------------------------------

SERIAL_PORT = "COM10"
BAUD_RATE = 115200


# ------------------------------------------------------------
# FIREBASE PROJECT
# ------------------------------------------------------------

PROJECT_ID = "home-care-9a355"

# Firebase API key is NOT stored in this file.
# It is read from the Windows environment variable.
FIREBASE_API_KEY = os.environ.get("HOME_CARE_FIREBASE_API_KEY")


# ------------------------------------------------------------
# FIRESTORE DOCUMENT
# ------------------------------------------------------------

FIRESTORE_URL = (
    f"https://firestore.googleapis.com/v1/"
    f"projects/{PROJECT_ID}/databases/(default)/documents/"
    f"hazards/home_001"
)


# ============================================================
# FIRESTORE VALUE HELPERS
# ============================================================

def firestore_string(value):
    return {
        "stringValue": value
    }


def firestore_bool(value):
    return {
        "booleanValue": value
    }


def firestore_timestamp():
    return {
        "timestampValue": datetime.now(
            timezone.utc
        ).isoformat().replace("+00:00", "Z")
    }


# ============================================================
# FIREBASE WRITE
# ============================================================

def send_hazard(hazard, active, severity, message):

    if not FIREBASE_API_KEY:
        print(
            "[FIREBASE ERROR] "
            "HOME_CARE_FIREBASE_API_KEY is not set."
        )
        return False

    data = {
        "fields": {
            "hazard": firestore_string(hazard),
            "active": firestore_bool(active),
            "severity": firestore_string(severity),
            "message": firestore_string(message),
            "timestamp": firestore_timestamp(),
        }
    }

    url = FIRESTORE_URL + "?key=" + FIREBASE_API_KEY

    try:

        response = requests.patch(
            url,
            json=data,
            timeout=10
        )

        if response.status_code in (200, 201):

            print(
                f"[FIREBASE] {hazard} "
                f"active={active}"
            )

            return True

        else:

            print(
                "[FIREBASE ERROR]",
                response.status_code
            )

            print(response.text)

            return False

    except requests.RequestException as e:

        print("[FIREBASE ERROR]", e)

        return False


# ============================================================
# EVENT PROCESSING
# ============================================================

def process_event(event):

    event = event.strip()

    if not event.startswith("EVENT="):
        return

    event = event.replace(
        "EVENT=",
        "",
        1
    ).strip()

    print(f"[WEMOS] EVENT={event}")


    # --------------------------------------------------------
    # FIRE
    # --------------------------------------------------------

    if event == "FIRE":

        send_hazard(
            hazard="fire",
            active=True,
            severity="critical",
            message="Fire detected by flame sensor"
        )


    # --------------------------------------------------------
    # GAS LEAK
    # --------------------------------------------------------

    elif event == "GAS_LEAK":

        send_hazard(
            hazard="gas",
            active=True,
            severity="critical",
            message="Possible gas leak detected"
        )


    # --------------------------------------------------------
    # BREAK-IN
    # --------------------------------------------------------

    elif event == "BREAK_IN":

        send_hazard(
            hazard="break_in",
            active=True,
            severity="critical",
            message="Possible intrusion detected"
        )


    # --------------------------------------------------------
    # ELDERLY EMERGENCY
    # --------------------------------------------------------

    elif event == "ELDERLY_EMERGENCY":

        send_hazard(
            hazard="emergency",
            active=True,
            severity="critical",
            message="Elderly emergency assistance required"
        )


    # --------------------------------------------------------
    # NORMAL
    # --------------------------------------------------------

    elif event == "NORMAL":

        send_hazard(
            hazard="normal",
            active=False,
            severity="normal",
            message="No active hazard"
        )


# ============================================================
# MAIN
# ============================================================

def main():

    print()
    print("==============================================")
    print("          HOME CARE FIREBASE BRIDGE")
    print("==============================================")
    print()

    print(f"Serial Port : {SERIAL_PORT}")
    print(f"Baud Rate   : {BAUD_RATE}")
    print(f"Firebase    : {PROJECT_ID}")
    print()


    # --------------------------------------------------------
    # CHECK FIREBASE KEY
    # --------------------------------------------------------

    if not FIREBASE_API_KEY:

        print("ERROR:")
        print(
            "Firebase API key was not found."
        )

        print()
        print(
            "Set the Windows environment variable:"
        )

        print(
            "HOME_CARE_FIREBASE_API_KEY"
        )

        print()

        return


    print("Firebase API key: FOUND")
    print()


    # --------------------------------------------------------
    # CONNECT TO WEMOS
    # --------------------------------------------------------

    try:

        ser = serial.Serial(
            SERIAL_PORT,
            BAUD_RATE,
            timeout=1
        )

        print("WEMOS CONNECTED")
        print()

    except Exception as e:

        print()
        print("ERROR CONNECTING TO WEMOS:")
        print(e)
        print()

        print("Check:")
        print("1. Wemos is connected")
        print("2. COM10 is correct")
        print("3. Arduino Serial Monitor is CLOSED")

        print()

        return


    # --------------------------------------------------------
    # READ SERIAL DATA
    # --------------------------------------------------------

    last_event = None

    try:

        while True:

            line = ser.readline().decode(
                "utf-8",
                errors="ignore"
            ).strip()


            if not line:
                continue


            print(f"[SERIAL] {line}")


            # Only process EVENT lines
            if line.startswith("EVENT="):

                event = line.replace(
                    "EVENT=",
                    "",
                    1
                ).strip()


                # Prevent writing the same event
                # to Firebase every second.
                if event != last_event:

                    process_event(line)

                    last_event = event


    except KeyboardInterrupt:

        print()
        print("Bridge stopped.")


    finally:

        ser.close()


# ============================================================
# START
# ============================================================

if __name__ == "__main__":
    main()