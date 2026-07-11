# BitCar

A modern Flutter marketplace application for buying, selling, and comparing new and used cars.

BitCar is a role-based mobile application built with Flutter, following Clean Architecture and the BLoC pattern. It provides a seamless experience for buyers, sellers, and administrators through a scalable and maintainable codebase powered by Firebase.

---

## Features

- Secure authentication with Firebase Authentication.
- Browse new and used cars.
- Advanced search and filtering.
- Car comparison.
- Add, edit, and delete car listings.
- Favorites management.
- Role-based access (Admin, Seller, Buyer).
- Banner advertisements management.
- Pagination and lazy loading.
- Responsive and reusable UI components.
- Error handling and user-friendly feedback.

---

## Screenshots

| Register | Home |
|----------|------|
| ![](screenshots/register.jpg) | ![](screenshots/home.jpg) |

| Filter | Car Details |
|---------|-------------|
| ![](screenshots/filter.jpg) | ![](screenshots/car_details.jpg) |

| Compare | Favorites / My Cars |
|----------|---------------------|
| ![](screenshots/compare.jpg) | ![](screenshots/my_cars.jpg) |

| Profile |
|----------|
| ![](screenshots/profile.jpg) |

---

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- BLoC / Cubit
- Provider
- Dio
- SharedPreferences
- GetIt
- Repository Pattern
- Clean Architecture
- Git & GitHub

---

## Architecture

This project follows **Clean Architecture** to ensure scalability, maintainability, and separation of concerns.

```
Presentation
     │
     ▼
   Domain
     │
     ▼
     Data
     │
     ▼
 Firebase
```

---

## Getting Started

```bash
git clone https://github.com/abdobittar99/bitcar-app.git

cd bitcar-app

flutter pub get

flutter run
```

---

## Project Structure

```
lib/
├── core/
├── modules/
├── shared/
├── services/
└── main.dart
```

---

## Author

**Abdalrahman Bittar**

GitHub:
https://github.com/abdobittar99