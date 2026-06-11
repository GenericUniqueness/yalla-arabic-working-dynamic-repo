import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses =
      CourseService.initialCourses; // start with zero flicker
  bool _loaded = false;

  List<Course> get courses => _courses;
  bool get loaded => _loaded;

  CourseProvider() {
    _load();
  }

  Future<void> _load() async {
    final courses = await CourseService.load();
    _courses = courses;
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loaded = false;
    notifyListeners();
    await _load();
  }
}
