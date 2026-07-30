const { IoTDataPlaneClient, PublishCommand } = require('@aws-sdk/client-iot-data-plane');

// Initialize IoT Data Plane Client with the regional ATS endpoint
const iotClient = new IoTDataPlaneClient({
    endpoint: `https://${process.env.IOT_ENDPOINT}`,
});

exports.handler = async (event) => {
    console.log('Received Control Request:', JSON.stringify(event));

    // Extract path parameter: /devices/{device_id}/control
    const deviceId = event.pathParameters ? event.pathParameters.device_id : null;

    if (!deviceId) {
        return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Missing device_id in path parameters' }),
        };
    }

    let body;
    try {
        body = event.body ? JSON.parse(event.body) : {};
    } catch (err) {
        return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Invalid JSON body' }),
        };
    }

    const { command, payload } = body;

    if (!command) {
        return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Field "command" is required in request body' }),
        };
    }

    const topic = `telemetry/${deviceId}/control`;
    const messagePayload = {
        target_device: deviceId,
        command: command,
        payload: payload || {},
        timestamp: new Date().toISOString(),
    };

    try {
        const publishCommand = new PublishCommand({
            topic: topic,
            qos: 1, // At least once delivery
            payload: Buffer.from(JSON.stringify(messagePayload)),
        });

        await iotClient.send(publishCommand);

        console.log(`Successfully published control command to ${topic}`);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
            },
            body: JSON.stringify({
                status: 'SUCCESS',
                device_id: deviceId,
                published_topic: topic,
                sent_command: messagePayload,
            }),
        };
    } catch (err) {
        console.error('Error publishing MQTT message:', err);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Failed to deliver MQTT command', details: err.message }),
        };
    }
};