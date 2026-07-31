import os
import time
import json
import random
from datetime import datetime, timezone
from awscrt import io, mqtt
from awsiot import mqtt_connection_builder, iotshadow

# Environment / Configuration Parameters
ENDPOINT = os.getenv("AWS_IOT_ENDPOINT")
CLIENT_ID = os.getenv("CLIENT_ID", "iot-fleet-dev-sim-01")
PATH_TO_CERT = os.getenv("CERT_PATH", "../certs/certificate.pem")
PATH_TO_KEY = os.getenv("KEY_PATH", "../certs/private.key")
PATH_TO_ROOT_CA = os.getenv("ROOT_CA_PATH", "../certs/root-CA.crt")

TELEMETRY_TOPIC = f"telemetry/{CLIENT_ID}/data"
CONTROL_TOPIC = f"telemetry/{CLIENT_ID}/control"

# Global state for dynamic telemetry interval (default: 10 seconds)
PUBLISH_INTERVAL = 10.0
shadow_client = None

# Callback when a control message is received over MQTT
def on_message_received(topic, payload, dup, qos, retain, **kwargs):
    global PUBLISH_INTERVAL
    try:
        data = json.loads(payload.decode('utf-8'))
        print(f"[{CLIENT_ID}] 📥 RECEIVED CONTROL COMMAND on '{topic}': {json.dumps(data, indent=2)}",
              flush=True
        )

        command = data.get("command")
        cmd_payload = data.get("payload", {})

        if command == "SET_INTERVAL":
            new_interval = cmd_payload.get("interval_seconds")
            if new_interval and isinstance(new_interval, (int, float)) and new_interval > 0:
                PUBLISH_INTERVAL = float(new_interval)
                print(f"[{CLIENT_ID}] ⏱️ Dynamically updated telemetry interval to {PUBLISH_INTERVAL}s!")
            else:
                print(f"[{CLIENT_ID}] ⚠️ Invalid 'interval_seconds' value: {new_interval}")

        elif command == "RESTART":
            print(f"[{CLIENT_ID}] 🔄 Simulating device restart sequence...")
            time.sleep(2)
            print(f"[{CLIENT_ID}] ✅ Device back online!")

        else:
            print(f"[{CLIENT_ID}] ℹ️ Received unhandled command: {command}")

    except Exception as e:
        print(f"[{CLIENT_ID}] Error handling control payload: {e}")

def on_shadow_delta_updated(delta_event):
    global PUBLISH_INTERVAL, shadow_client
    print(
        f"[{CLIENT_ID}] ⚡ SHADOW DELTA RECEIVED: {delta_event.state}",
        flush=True
    )

    desired_state = delta_event.state
    updated_reported = {}

    # Check if shadow requested a new interval
    if "interval_seconds" in desired_state:
        new_interval = desired_state["interval_seconds"]
        if isinstance(new_interval,(int, float)) and new_interval > 0:
            PUBLISH_INTERVAL = float(new_interval)
            updated_reported["interval_seconds"] = PUBLISH_INTERVAL
            print(
                f"[{CLIENT_ID}] ⏱️ Shadow synced telemetry interval to {PUBLISH_INTERVAL}s!"
            )

    # Sync reported state back to AWS IoT Shadow
    if updated_reported and shadow_client:
        update_request = iotshadow.UpdateShadowRequest(
            thing_name=CLIENT_ID,
            state=iotshadow.ShadowState(reported=updated_reported),
        )
        shadow_client.publish_update_shadow(
            update_request, mqtt.QoS.AT_LEAST_ONCE
        )
        print(
            f"[{CLIENT_ID}] ✅ REPORTED SHADOW STATE SYNCED: {updated_reported}"
        )

def main():
    global shadow_client

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

    # Subscribe to control topic
    print(f"[{CLIENT_ID}] Subscribing to control topic: {CONTROL_TOPIC}...")
    subscribe_future, _ = mqtt_connection.subscribe(
        topic=CONTROL_TOPIC,
        qos=mqtt.QoS.AT_LEAST_ONCE,
        callback=on_message_received
    )
    subscribe_future.result()
    print(f"[{CLIENT_ID}] ✅ Subscribed to {CONTROL_TOPIC}")

    # Setup Shadow Client & Subscribe to Shadow Delta
    shadow_client = iotshadow.IotShadowClient(mqtt_connection)
    delta_sub_request = iotshadow.ShadowDeltaUpdatedSubscriptionRequest(
        thing_name=CLIENT_ID
    )
    sub_future, _ = shadow_client.subscribe_to_shadow_delta_updated_events(
        delta_sub_request, mqtt.QoS.AT_LEAST_ONCE, on_shadow_delta_updated
    )
    sub_future.result()
    print(
        f"[{CLIENT_ID}] ✅ Subscribed to Shadow Delta events for {CLIENT_ID}"
    )

    # Publish initial shadow state on startup
    init_shadow_request = iotshadow.UpdateShadowRequest(
        thing_name=CLIENT_ID,
        state=iotshadow.ShadowState(
            reported={"interval_seconds": PUBLISH_INTERVAL, "status": "OK"}
        ),
    )
    shadow_client.publish_update_shadow(
        init_shadow_request, mqtt.QoS.AT_LEAST_ONCE
    )

    # Telemetry loop
    try:
        while True:
            payload = {
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "temperature": round(random.uniform(20.0, 30.0), 2),
                "humidity": round(random.uniform(40.0, 70.0), 2),
                "battery": round(random.uniform(80.0, 100.0), 2),
                "status": "OK"
            }

            mqtt_connection.publish(
                topic=TELEMETRY_TOPIC,
                payload=json.dumps(payload),
                qos=mqtt.QoS.AT_LEAST_ONCE
            )
            print(f"[{CLIENT_ID}] 📤 Published telemetry (Next message in {PUBLISH_INTERVAL}s)")
            time.sleep(PUBLISH_INTERVAL)
    except KeyboardInterrupt:
        print(f"[{CLIENT_ID}] Disconnecting...")
        disconnect_future = mqtt_connection.disconnect()
        disconnect_future.result()

if __name__ == "__main__":
    main()