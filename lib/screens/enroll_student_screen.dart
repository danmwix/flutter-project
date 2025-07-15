import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class EnrollStudentScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const EnrollStudentScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  _EnrollStudentScreenState createState() => _EnrollStudentScreenState();
}

class _EnrollStudentScreenState extends State<EnrollStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _admissionNumberController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _admissionNumberController.dispose();
    super.dispose();
  }

  Future<void> _enrollStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final admissionNumber = _admissionNumberController.text.trim().toUpperCase();
        print('Querying for admissionNumber: $admissionNumber'); // Debug log

        // Query users by admissionNumber
        final userQuery = await _firestore
            .collection('users')
            .where('admissionNumber', isEqualTo: admissionNumber)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw 'No user found with admission number "$admissionNumber". Please check the number and try again.';
        }

        final userDoc = userQuery.docs.first;
        final studentId = userDoc.id;
        final studentData = userDoc.data();
        final studentName = studentData['name']?.trim() ?? 'Unknown Student';
        final role = studentData['role'] as String? ?? 'none';
        print('Found student: $studentName, ID: $studentId, Role: $role'); // Debug log

        // If role is missing or "none", update to "student"
        if (role != 'student') {
          print('Updating role to "student" for user: $studentId'); // Debug log
          await _firestore.collection('users').doc(studentId).update({
            'role': 'student',
          });
        }

        // Check for existing enrollment
        final enrollmentId = '${widget.courseId}_$studentId';
        final enrollmentDoc = await _firestore.collection('enrollments').doc(enrollmentId).get();
        if (enrollmentDoc.exists) {
          throw 'Student $studentName is already enrolled in this course';
        }

        // Verify course exists
        final courseDoc = await _firestore.collection('courses').doc(widget.courseId).get();
        if (!courseDoc.exists) {
          throw 'Course not found';
        }

        // Create enrollment
        print('Creating enrollment with ID: $enrollmentId'); // Debug log
        await _firestore.collection('enrollments').doc(enrollmentId).set({
          'courseId': widget.courseId,
          'studentId': studentId,
          'studentName': studentName,
          'enrolledAt': FieldValue.serverTimestamp(),
          'grades': {},
          'assignmentsSubmitted': [],
          'quizzesSubmitted': [],
        });

        // Verify enrollment creation
        final createdEnrollment = await _firestore.collection('enrollments').doc(enrollmentId).get();
        if (!createdEnrollment.exists) {
          throw 'Failed to verify enrollment creation for $enrollmentId';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student enrolled successfully!'),
              backgroundColor: kSuccessColor,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        print('Enrollment error: $e'); // Debug log
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: kErrorColor,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        prefixIcon: Icon(icon, color: kTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kErrorColor),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: kTextColor,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: kTextColor)
          : Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enroll Student - ${widget.courseTitle}'),
        backgroundColor: kPrimaryColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryColor, kSecondaryColor],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.person_add, size: 100, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'Enroll a Student',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _admissionNumberController,
                    label: 'Admission Number',
                    icon: Icons.badge,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter the admission number';
                      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value)) return 'Invalid admission number format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildButton(
                    onPressed: _isLoading ? null : _enrollStudent,
                    label: 'Enroll Student',
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}