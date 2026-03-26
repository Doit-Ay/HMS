# CureIt — Comprehensive Hospital Management System (iOS)

🚑 Overview
CureIt is a comprehensive, scalable, and secure Hospital Management System designed as a native iOS application using Swift, SwiftUI, and Firebase. The goal was to create a unified platform that streamlines hospital operations while offering a seamless experience for patients, doctors, lab technicians, and administrative staff.

This app is not built for a single hospital but designed to be easily adopted and customized across different healthcare institutions, ensuring high operational efficiency.

🎯 Features

🧑‍⚕️ Patient Module
- Schedule and manage appointments with doctors seamlessly.
- Use an AI-powered health assistant (`AITriageService`) for preliminary symptom checking and sorting.
- Voice-enabled data input and navigation (`SpeechRecognizer`) for an accessible user experience.
- View digital prescriptions and effortlessly download medical invoices directly to your device.

👨‍⚕️ Doctor Module
- View detailed appointment schedules.
- Access comprehensive patient data, update health records, and view past medical history.
- Write clinical consultation notes and instantly generate digital prescriptions (`PrescriptionPDFGenerator`).
- Track essential medical inventory and oversee requested tests.

🏥 Admin & Staff Module
- Manage hospital staff, assign user roles (`UserRole`), and oversee broader system access.
- Oversee billing, digital payments, and checkout via an integrated Razorpay payment gateway (`RazorpayWrapper`).
- Generate real-time hospital-wide invoices and comprehensive revenue PDF reports (`RevenuePDFGenerator`).
- Track system activities and operations through a dedicated audit log (`ActivityLogManager`) for security auditing.

💉 Lab Technician Module
- Lab technicians can manage test requests and process lab results efficiently.
- Real-time tracking and management of hospital inventory and critical medicine stock levels (`InventoryRepository`).

💡 Non-Functional Highlights
- **Scalable**: Built on a cloud-based backend architecture (Firebase Firestore) capable of horizontal scaling to handle thousands of concurrent users without performance drops.
- **Secure**: Implements role-based access control (RBAC), secure Email OTP authentication (`EmailOTPManager`), and secure, encrypted system activity logging to meet privacy requirements.
- **Accessible**: Features voice input support, an intuitive UI tailored for diverse age groups, and seamless navigation.
- **Fast & Reliable**: Robust local PDF caching (`PDFCacheManager`) allows for instantaneous report generation without server dependency; optimized database calls minimize latency.
- **Future-proof**: Supports the latest iOS versions, entirely built using modern SwiftUI, ensuring smooth updates, scalability, and maintainability.

🛠️ Tech Stack
- **Language**: Swift, SwiftUI
- **Backend & Database**: Firebase (Authentication, Firestore Database, Storage)
- **Payment Gateway**: Razorpay iOS SDK
- **Architecture**: Modular MVVM (Model-View-ViewModel) and role-based UI separation
- **Other Tools**: Core Speech (Speech Recognizer), PDFKit (Generators)

🌟 Approach & Development
The team’s vision was not only to meet functional requirements but to exceed expectations by focusing on user-centric design and robust engineering practices.

- Created role-specific layout domains (`Auth`, `Patient`, `Staff`, `Shared`) to reduce clutter and improve daily workflows for respective users.
- Emphasized modular UI and completely decoupled business logic using dedicated ViewModels and Repository managers.
- Integrated an AI-powered triage and chatbot approach to precisely guide patients and reduce the hospital staff's initial triage workload.
- Kept the accounting and consulting completely paper-free utilizing robust one-tap native PDF generators.
- Seamlessly integrated Razorpay checkouts ensuring secure and fast transactions for patients.

🚀 Outcome
The final solution is a fully integrated, all-in-one hospital management app, featuring:

- Dedicated patient interfaces equipped with AI-triage symptom checkers and voice command elements.
- Clean doctor dashboards for swift case handling and instant digital prescription formulation.
- Streamlined lab test requests and medicine inventory stock tracking for lab technicians.
- Powerful financial billing integration, system logs, and accounting dashboards for administrators.
- Accessibility-first design, ensuring inclusivity for all users.
- One-tap precise PDF report generation and export for prescriptions, invoices, and hospital administration metrics.
