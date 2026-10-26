import 'package:car_shop/features/car/cars_list/ui/cars_screen.dart';
import 'package:car_shop/features/compare/ui/compare_intro/compare_screen.dart';
import 'package:car_shop/features/favorite/ui/favorite_screen.dart';
import 'package:car_shop/features/feeds/ui/feed_screen.dart';
import 'package:car_shop/features/profile/ui/profile_screen.dart';
import 'package:flutter/material.dart';

final bottomNavTabs = [
  FeedScreen(),
  ComparePage(),
  CarsScreen(),
  FavoritesScreen(),
  ProfileScreen(),
];

const bottomNavItems = [
  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
  BottomNavigationBarItem(
    icon: Icon(Icons.compare_arrows_rounded),
    label: 'Compare',
  ),
  BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: ' Cars'),
  BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
];
