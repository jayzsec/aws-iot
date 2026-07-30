# AWS IoT Fleet Monitoring & Control — Web Dashboard

An **Astro.js** and **React** single-page web dashboard for real-time telemetry monitoring, user authentication, and bi-directional device control.

---

## 🌟 Key Features

- **🔐 AWS Cognito Authentication**: Secure sign-in workflow using AWS Cognito User Pools. Manages JWT `id_token` and `access_token` session storage and injects Authorization headers into API calls.
- **📊 Real-Time Telemetry Visualization**: Time-series line and area charts visualizing environmental metrics (**Temperature**, **Humidity**, **Battery level**) with dynamic interval aggregation (`1h`, `24h`, `7d`).
- **⚡ Bi-Directional Device Control Panel**: Interactive control interface to dispatch real-time commands (`SET_INTERVAL`, `RESTART`) down to edge devices via AWS API Gateway and IoT Core over mTLS MQTT.
- **📱 Responsive Dark-Mode UI**: Built with modern CSS utility tokens, glassmorphism UI cards, and toast notification alerts.

---

## 📁 Project Structure

```text
frontend/
├── public/
│   ├── favicon.ico
│   └── favicon.svg
├── src/
│   ├── components/
│   │   ├── AuthGuard.jsx       # Auth wrapper enforcing login redirection
│   │   ├── DashboardApp.jsx    # Main dashboard application container
│   │   ├── DeviceControl.jsx   # Control panel for sending downstream MQTT commands
│   │   └── TelemetryChart.jsx  # Interactive time-series chart component
│   ├── layouts/
│   │   └── Layout.astro        # Base HTML layout template
│   ├── lib/
│   │   └── api.js              # API service client for Cognito & HTTP API Gateway
│   ├── pages/
│   │   ├── index.astro         # Main dashboard page route (/)
│   │   └── login.astro         # Authentication login page route (/login)
│   └── styles/
│       └── global.css          # Dark-mode styling tokens and layout utilities
├── astro.config.mjs            # Astro configuration with React integration
├── package.json                # Project dependencies
└── tsconfig.json               # TypeScript configuration
```

---

## ⚙️ Environment Configuration

Create a `.env` file inside the `frontend/` directory with your deployed infrastructure outputs:

```env
PUBLIC_API_GATEWAY_URL=https://<api-id>.execute-api.ap-southeast-2.amazonaws.com
PUBLIC_COGNITO_USER_POOL_ID=ap-southeast-2_xxxxxxxxx
PUBLIC_COGNITO_APP_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
PUBLIC_AWS_REGION=ap-southeast-2
```

> **Tip**: You can get these values directly from Terraform outputs after running `terraform apply`:
> ```bash
> terraform output api_gateway_url
> terraform output cognito_user_pool_id
> terraform output cognito_app_client_id
> ```

---

## 🚀 Commands

All commands are run from the `frontend/` directory:

| Command | Description |
| :--- | :--- |
| `npm install` | Installs dependencies (`astro`, `@astrojs/react`, `react`, `react-dom`, etc.) |
| `npm run dev` | Starts local development server at `http://localhost:4321` |
| `npm run build` | Builds production bundle to `./dist/` |
| `npm run preview` | Previews production build locally |

---

## 🔐 API & Security Integration

- **`GET /telemetry?device_id={id}&range={1h|24h|7d}`**: Fetches aggregated time-series data from TimescaleDB via Query Lambda. Requires `Authorization: Bearer <id_token>`.
- **`POST /devices/{id}/control`**: Dispatches downstream commands (`SET_INTERVAL`, `RESTART`) to Control Lambda → AWS IoT Data Plane. Requires `Authorization: Bearer <id_token>`.
