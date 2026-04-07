# 🏛️ GovEase - Digital Local Government Platform

![GovEase Project Banner](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge) 
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white) 
![React](https://img.shields.io/badge/react-%2320232a.svg?style=for-the-badge&logo=react&logoColor=%2361DAFB)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)

**GovEase** is a unified, cross-platform e-governance ecosystem designed to modernize civic operations in Sri Lanka. It bridges the gap between the public and government officials by digitizing public service requests, document verification, and complaint management.

## 🌟 Key Features

* **📱 Multi-Role Mobile App (Flutter):** A single app with dynamic routing for Citizens and Grama Niladhari (GN) Officers.
* **💻 Glassmorphic Web Dashboard (React):** A high-fidelity command center for Divisional Secretariat (DS) Admins.
* **🔒 End-to-End Encryption:** Client-side AES-256 encryption ensures citizen data (NIC, Address) remains secure and obfuscated in the database.
* **📄 Digital Document Engine:** Citizens can apply for certificates, upload evidence, and track real-time status. GN Officers can approve/reject securely via the app.
* **⚠️ Hazard Escalation System:** Public complaints are monitored and automatically escalated to DS Admins if neglected by ground staff.
* **🗑️ Dynamic Waste Schedules:** DS Admins can update district schedules, syncing instantly with citizens' mobile apps.

---

## 🛠️ Technology Stack

**Mobile Frontend (Citizens & Officers)**
- Flutter / Dart
- Provider / Riverpod (State Management)
- Offline Cache (Hive)

**Web Frontend (DS Admins)**
- React.js / Vite
- Tailwind CSS
- Framer Motion

**Backend & Cloud Infrastructure**
- Google Firebase (Firestore, Auth, Storage, Cloud Functions)
- WebSockets for Real-time Document Tracking

---

## 📂 Project Structure

```text
GovEase/
├── Mobile App (Citizen-GN Officer)/  # Flutter mobile application
├── Admin Panel (Web Based)/          # React + Vite web dashboard
│   ├── frontend/                     # React application
│   └── backend/                      # Node.js secondary scripts
└── functions/                        # Firebase Cloud Functions
```

---

## 🚀 Getting Started

### 1. Mobile App Setup (Flutter)
```bash
cd "Mobile App (Citizen-GN Officer)"
flutter pub get
flutter run
```

### 2. Web Admin Panel Setup (React)
```bash
cd "Admin Panel (Web Based)/frontend"
npm install
npm run dev
```

*(Note: Ensure you have Firebase configuration files `google-services.json` and `firebase.js` in their respective directories before running).*

---

## 👥 Contributors

This project was developed by a team of 6 engineers:
- **Core Citizen Identity & Security** (Auth, AES Encryption)
- **Public Service Engine** (Applications, Payments, Blob Storage)
- **GN Officer RBAC Routing** (Navigations, Web Setup, Dashboards)
- **Backend Utilities & Workflows** (Offline Sync, AI Chatbot, Backend Logic)
- **Public Hazard & Escalation System** (Complaints, Notifications)
- **DS Admin Overlord & Civic Directories** (React Architecture, CSS Branding)

---

## 📝 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
