import os
import time
import json
from awscrt import io, mqtt
from awsiot import mqtt_connection_builder, iotidentity

# Configuration Parameters
ENDPOINT = os.getenv("AWS_IOT_ENDPOINT")
CLAIM_CERT = os.getenv("CLAIM_CERT_PATH", "/app/certs/claim_certificate.pem")
CLAIM_KEY = os.getenv("CLAIM_KEY_PATH", "/app/certs/claim_private.key")
ROOT_CA = os.getenv("ROOT_CA_PATH", "/app/certs/root-CA.crt")
TEMPLATE_NAME = "iot-fleet-platform-dev-fleet-templ"

TIMESTAMP = int(time.time())
SERIAL_NUMBER = f"auto-{TIMESTAMP}"
CLIENT_ID = f"iot-fleet-platform-dev-sim-claim-{TIMESTAMP}"

identity_client = None

def on_register_thing_accepted(response):
    print(f"\n✅ DEVICE PROVISIONED SUCCESSFULLY!", flush=True)
    print(f"📌 Created Thing Name: {response.thing_name}", flush=True)

def on_create_keys_accepted(response):
    print("\n🔑 New X.509 Certificate and Private Key received from AWS IoT CA!", flush=True)

    os.makedirs("/app/certs/provisioned", exist_ok=True)
    cert_path = f"/app/certs/provisioned/{SERIAL_NUMBER}_cert.pem"
    key_path = f"/app/certs/provisioned/{SERIAL_NUMBER}_key.pem"

    with open(cert_path, "w") as f:
        f.write(response.certificate_pem)
    with open(key_path, "w") as f:
        f.write(response.private_key)

    print(f"💾 Permanent credentials saved to {cert_path}", flush=True)

    print(f"📋 Registering Thing '{SERIAL_NUMBER}' using template '{TEMPLATE_NAME}'...", flush=True)
    register_request = iotidentity.RegisterThingRequest(
        template_name=TEMPLATE_NAME,
        certificate_ownership_token=response.certificate_ownership_token,
        parameters={"SerialNumber": SERIAL_NUMBER}
    )
    identity_client.publish_register_thing(register_request, mqtt.QoS.AT_LEAST_ONCE)

def main():
    global identity_client
    print(f"🚀 Initializing Provisioning Workflow for Client ID: {CLIENT_ID}...", flush=True)

    event_loop = io.EventLoopGroup(1)
    host_resolver = io.DefaultHostResolver(event_loop)
    client_bootstrap = io.ClientBootstrap(event_loop, host_resolver)

    mqtt_connection = mqtt_connection_builder.mtls_from_path(
        endpoint=ENDPOINT,
        cert_filepath=CLAIM_CERT,
        pri_key_filepath=CLAIM_KEY,
        client_bootstrap=client_bootstrap,
        ca_filepath=ROOT_CA,
        client_id=CLIENT_ID
    )

    mqtt_connection.connect().result()
    print("Connected to AWS IoT Core using Claim Certificate!", flush=True)

    identity_client = iotidentity.IotIdentityClient(mqtt_connection)

    # 1. Subscribe to Certificate Creation Response (Unpack tuple)
    sub_keys_req = iotidentity.CreateKeysAndCertificateSubscriptionRequest()
    keys_future, _ = identity_client.subscribe_to_create_keys_and_certificate_accepted(
        sub_keys_req, mqtt.QoS.AT_LEAST_ONCE, on_create_keys_accepted
    )
    keys_future.result()

    # 2. Subscribe to Thing Registration Response (Unpack tuple)
    sub_reg_req = iotidentity.RegisterThingSubscriptionRequest(template_name=TEMPLATE_NAME)
    reg_future, _ = identity_client.subscribe_to_register_thing_accepted(
        sub_reg_req, mqtt.QoS.AT_LEAST_ONCE, on_register_thing_accepted
    )
    reg_future.result()

    # 3. Publish request for new credentials
    print("📡 Requesting new X.509 Certificate and Private Key...", flush=True)
    identity_client.publish_create_keys_and_certificate(
        iotidentity.CreateKeysAndCertificateRequest(), mqtt.QoS.AT_LEAST_ONCE
    )

    time.sleep(5)
    mqtt_connection.disconnect().result()

if __name__ == "__main__":
    main()