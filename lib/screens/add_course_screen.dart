import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCourseScreen extends StatefulWidget {
  final String? courseId;
  final Map<String, dynamic>? courseData;

  const AddCourseScreen({super.key, this.courseId, this.courseData});

  @override
  _AddCourseScreenState createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _language = 'English';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.courseData != null) {
      _titleController.text = widget.courseData!['title'] ?? '';
      _descriptionController.text = widget.courseData!['description'] ?? '';
      _language = widget.courseData!['language'] ?? 'English';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveCourse() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw 'User not authenticated';

        final courseData = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'language': _language,
          'teacherId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Check for duplicate course
        if (widget.courseId == null) {
          final courseQuery = await FirebaseFirestore.instance
              .collection('courses')
              .where('title', isEqualTo: _titleController.text.trim())
              .where('teacherId', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (courseQuery.docs.isNotEmpty) {
            throw 'A course with this title already exists';
          }
        }

        String? courseId;
        if (widget.courseId != null) {
          await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update(courseData);
          courseId = widget.courseId;
        } else {
          final docRef = await FirebaseFirestore.instance.collection('courses').add(courseData);
          courseId = docRef.id;
        }

        if (mounted) {
          Navigator.pop(context, courseId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course saved successfully!'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving course: $e'), backgroundColor: const Color(0xFFF44336)),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.add_circle, size: 100, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      widget.courseId == null ? 'Add New Course' : 'Edit Course',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create or update a course for your students',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Course Title',
                        prefixIcon: const Icon(Icons.book, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter the course title';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Course Description',
                        prefixIcon: const Icon(Icons.description, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter the course description';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _language,
                      items: ['English', 'Swahili'].map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                      onChanged: (value) => setState(() => _language = value!),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Language',
                        prefixIcon: const Icon(Icons.language, color: Colors.blue),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSaveCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Color(0xFF0D47A1))
                          : Text(
                              widget.courseId == null ? 'Create Course' : 'Update Course',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}