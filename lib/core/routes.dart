import 'package:flutter/material.dart';
import 'package:student_accomdation/pages/accommodation_detail_screen.dart';
import 'package:student_accomdation/pages/housing_staff_screen.dart';
import 'package:student_accomdation/pages/login.dart';
import 'package:student_accomdation/pages/register.dart';
import 'package:student_accomdation/pages/home.dart';

class RouteManager {
  static const String loginPage = "/login";
  static const String registerPage = "/register";
  static const String homePage = "/home";
  static const String housingStaff = "/housingStaff";
  static const String accommodationDetail = "/accommodationDetail";

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loginPage:
        return MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        );
      case registerPage:
        return MaterialPageRoute(
          builder: (context) => RegisterScreen(),
        );
      case homePage:
        return MaterialPageRoute(
          builder: (context) => const StudentHomePage(),
        );
      // Add to your route manager or main navigation
      case RouteManager.housingStaff:
        return MaterialPageRoute(builder: (_) => const HousingStaffScreen());
      case RouteManager.accommodationDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
            builder: (_) => AccommodationDetailScreen(
                  accommodationId: args['accommodationId'],
                  landlordId: args['landlordId'],
                  accommodationData: args['accommodationData'],
                ));
      default:
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text("Route Not Found")),
          ),
        );
    }
  }
}
