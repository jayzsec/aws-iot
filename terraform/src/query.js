const { Client } = require('pg');
const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

const ssm = new SSMClient({});
let cachedDbPassword = null;

async function getDbPassword() {
    if (cachedDbPassword) return cachedDbPassword;

    const command = new GetParameterCommand({
        Name: process.env.SSM_PARAM_NAME,
        WithDecryption: true,
    });

    const response = await ssm.send(command);
    cachedDbPassword = response.Parameter.Value;
    return cachedDbPassword;
}

exports.handler = async (event) => {
    console.log('Received HTTP Request:', JSON.stringify(event));

    const queryParams = event.queryStringParameters || {};
    const deviceId = queryParams.device_id;
    const range = queryParams.range || '1h'; // Default: past 1 hour

    if (!deviceId) {
        return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Missing required query parameter: device_id' }),
        };
    }

    // Parse relative time window for query
    let interval = '1 hour';
    let bucketSize = '1 minute';

    if (range === '24h') {
        interval = '24 hours';
        bucketSize = '15 minutes';
    } else if (range === '7d') {
        interval = '7 days';
        bucketSize = '1 hour';
    }

    let dbClient;

    try {
        const password = await getDbPassword();

        dbClient = new Client({
            host: process.env.DB_HOST,
            port: parseInt(process.env.DB_PORT || '6432', 10),
            database: process.env.DB_NAME,
            user: process.env.DB_USER,
            password: password,
            connectionTimeoutMillis: 3000,
        });

        await dbClient.connect();

        // Query bucketed time-series aggregates using TimescaleDB time_bucket
        const query = `
      SELECT 
        time_bucket($1::interval, time) AS bucket,
        ROUND(AVG(temperature)::numeric, 2) AS avg_temperature,
        ROUND(AVG(humidity)::numeric, 2) AS avg_humidity,
        ROUND(AVG(battery)::numeric, 2) AS avg_battery
      FROM sensor_telemetry
      WHERE device_id = $2 
        AND time >= NOW() - $3::interval
      GROUP BY bucket
      ORDER BY bucket ASC;
    `;

        const result = await dbClient.query(query, [bucketSize, deviceId, interval]);

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
            },
            body: JSON.stringify({
                device_id: deviceId,
                time_range: range,
                data_points: result.rows.length,
                telemetry: result.rows,
            }),
        };
    } catch (err) {
        console.error('Database query error:', err);
        return {
            statusCode: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Internal Database Error', details: err.message }),
        };
    } finally {
        if (dbClient) {
            await dbClient.end();
        }
    }
};