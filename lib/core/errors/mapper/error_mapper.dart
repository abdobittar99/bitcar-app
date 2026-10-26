import 'package:car_shop/core/enums/error_type.dart';
import 'package:car_shop/core/errors/exception.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ErrorMapper {
  static AppException map(Object error) {
    if (error is FirebaseAuthException) {
      return AppException(
        message: mapFirebaseAuth(error),
        type: ErrorType.auth,
      );
    }

    if (error is FirebaseException) {
      return AppException(
        message: mapFirestore(error),
        type: firestoreType(error),
      );
    }

    if (error is PlatformException) {
      return AppException(
        message: mapPlatform(error),
        type: ErrorType.platform,
      );
    }

    if (error is AppException) {
      return error;
    }

    return AppException(
      message: 'Something went wrong, please try again',
      type: ErrorType.unknown,
    );
  }

  static String mapFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts, try again later';
      case 'User not logged in':
        return 'You are logged out ';
      default:
        return 'Email or password is incorrect';
    }
  }

  static String mapFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action';

      case 'not-found':
        return 'Requested car not found';

      case 'already-exists':
        return 'This car already exists';

      case 'unavailable':
        return 'Service temporarily unavailable';

      case 'deadline-exceeded':
        return 'Request timed out, try again';

      case 'cancelled':
        return 'Operation was cancelled';

      case 'aborted':
        return 'Operation aborted, please retry';

      case 'resource-exhausted':
        return 'Too many requests, slow down';

      default:
        return 'Database operation failed';
    }
  }

  static String mapPlatform(PlatformException e) {
    final msg = e.message?.toLowerCase() ?? '';

    if (msg.contains('network')) {
      return 'No internet connection';
    }

    if (msg.contains('permission')) {
      return 'Permission denied';
    }

    if (msg.contains('credential')) {
      return 'Invalid login credentials';
    }

    if (msg.contains('timeout')) {
      return 'Request timed out';
    }

    return 'System error occurred';
  }

  static ErrorType firestoreType(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return ErrorType.permission;

      case 'not-found':
        return ErrorType.notFound;

      case 'unavailable':
      case 'deadline-exceeded':
        return ErrorType.network;

      default:
        return ErrorType.firestore;
    }
  }
}
