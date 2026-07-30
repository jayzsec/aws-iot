-- Connect to the iot_telemetry database
\c iot_telemetry;

-- Create the base telemetry table
CREATE TABLE IF NOT EXISTS sensor_telemetry (
    time        TIMESTAMPTZ       NOT NULL,
    device_id   VARCHAR(64)       NOT NULL,
    temperature DOUBLE PRECISION  NULL,
    humidity    DOUBLE PRECISION  NULL,
    battery     DOUBLE PRECISION  NULL,
    status      VARCHAR(32)       NULL
);

-- Convert standard table into a TimescaleDB Hypertable partitioned by 'time'
SELECT create_hypertable('sensor_telemetry', 'time', if_not_exists => TRUE);

-- Create index for fast lookups by device_id and time
CREATE INDEX IF NOT EXISTS idx_device_time ON sensor_telemetry (device_id, time DESC);

-- Grant privileges to our unprivileged application user
GRANT ALL PRIVILEGES ON TABLE sensor_telemetry TO app_user;