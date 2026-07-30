import os
import time
import json
import random
from datetime import datetime, timezone
from awscrt import io, mqtt
from awsiot import mqtt_connection_builder

# Environment / Configuration Parameters
ENDPOINT = os.getenv("AWS_IOT_ENDPOINT")
CLIENT_ID = os.getenv("CLIENT_ID", "iot-fleet-dev-sim-01")
PATH_TO_CERT = os.getenv("CERT_PATH", "../certs/certificate.pem")
PATH_TO_KEY = os.getenv("KEY_PATH", "../certs/private.key")
PATH_TO_ROOT_CA = os.getenv("ROOT_CA_PATH", "../certs/root-CA.crt")
TOPIC = f"telemetry/{CLIENT_ID}/data"

def main():
    print(f"[{CLIENT_ID}] Initializing MQTT mTLS Connection to {ENDPOINT}...")

    event_loop_group = io.EventLoopGroup(1)
    host_resolver = io.DefaultHostResolver(event_loop_group)
    client_bootstrap = io.ClientBootstrap(event_loop_group, host_resolver)

    mqtt_connection = mqtt_connection_builder.mtls_from_path(
        endpoint=ENDPOINT,
        cert_filepath=PATH_TO_CERT,
        pri_key_filepath=PATH_TO_KEY,
        client_bootstrap=client_bootstrap,
        ca_filepath=PATH_TO_ROOT_CA,
        client_id=CLIENT_ID,
        clean_session=False,
        keep_alive_secs=30
    )

    connect_future = mqtt_connection.connect()
    connect_future.result()
    print(f"[{CLIENT_ID}] Connected to AWS IoT Core successfully!")

    # Telemetry loop
    battery_level = 100.0
    try:
        while True:
            # Simulate realistic environmental variations
            temperature = round(random.uniform(20.0, 32.0), 2)
            humidity = round(random.uniform(40.0, 75.0), 2)
            battery_level = max(0.0, round(battery_level - 0.1, 2))

            payload = {
                "clientId": CLIENT_ID,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "temperature": temperature,
                "humidity": humidity,
                "battery": battery_level,
                "status": "OK" if battery_level > 15 else "LOW_BATTERY"
            }

            message_json = json.dumps(payload)
            print(f"[{CLIENT_ID}] Publishing to {TOPIC}: {message_json}")

            mqtt_connection.publish(
                topic=TOPIC,
                payload=message_json,
                qos=mqtt.QoS.AT_LEAST_ONCE
            )

            time.sleep(5)  # Publish every 5 seconds

    except KeyboardInterrupt:
        print(f"[{CLIENT_ID}] Stopping simulator...")
        disconnect_future = mqtt_connection.disconnect()
        disconnect_future.result()

if __name__ == "__main__":
    main()