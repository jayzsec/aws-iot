
// This lambda handler
// runs inside VPC
// caches database credentials across warm invocations
// connects to PgBouncer on port 6432
// parses incoming mqtt payloads from IoT Core and executes a parameterized SQL INSERT

const { Client } = require('pg');
const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

// Global cache for warm Lambda executions
let cachedPassword = null;
const ssmClient = new SSMClient();

async function getDbPassword() {
    if (cachedPassword) return cachedPassword;

    const command = new GetParameterCommand({
        Name: process.env.SSM_PASS_PARAM_NAME,
        WithDecryption: true,
    });

    const response = await ssmClient.send(command);
    cachedPassword = response.Parameter.Value;
    return cachedPassword;
}

exports.handler = async (event) => {
    console.log("Received MQTT Event:", JSON.stringify(event));

    let client;
    try {
        const dbPassword = await getDbPassword();

        // Connect to PgBouncer
        client = new Client({
            host: process.env.DB_HOST,
            port: parseInt(process.env.DB_PORT || '6432', 10),
            database: process.env.DB_NAME || 'iot_telemetry',
            user: process.env.DB_USER || 'app_user',
            password: dbPassword,
            connectionTimeoutMillis: 5000,
        });

        await client.connect();

        // Extract payload fields
        const deviceId = event.device_id || event.clientId || 'unknown_device';
        const timestamp = event.timestamp ? new Date(event.timestamp) : new Date();
        const temperature = event.temperature ?? null;
        const humidity = event.humidity ?? null;
        const battery = event.battery ?? null;
        const status = event.status || 'OK';

        // Insert telemetry into TimescaleDB hypertable
        const query = `
            INSERT INTO sensor_telemetry (time, device_id, temperature, humidity, battery, status)
            VALUES ($1, $2, $3, $4, $5, $6);
        `;

        const values = [timestamp, deviceId, temperature, humidity, battery, status];

        await client.query(query, values);
        console.log(`Successfully ingested record for device: ${deviceId}`);

        return { statusCode: 200, body: 'Success'};
    } catch (error) {
        console.error("Ingestion Error:", error);
        throw error;
    } finally {
        if (client) {
            await client.end();
        }
    }
};
