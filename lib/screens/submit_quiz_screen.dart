import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class SubmitQuizScreen extends StatefulWidget {
  final String courseId;
  final String quizId;
  final Map<String, dynamic> quizData;
  final String? submissionId;
  final Map<String, dynamic>? submissionData;

  const SubmitQuizScreen({
    super.key,
    required this.courseId,
    required this.quizId,
    required this.quizData,
    this.submissionId,
    this.submissionData,
  });

  @override
  _SubmitQuizScreenState createState() => _SubmitQuizScreenState();
}

class _SubmitQuizScreenState extends State<SubmitQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _submissionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _studentName;

  @override
  void initState() {
    super.initState();
    if (widget.submissionData != null) {
      _submissionController.text = widget.submissionData!['content']?.trim() ?? '';
    }
    _fetchStudentName();
  }

  Future<void> _fetchStudentName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _studentName = userDoc.data()?['name']?.trim() ?? 'Unknown Student';
        });
      }
    }
  }

  Future<void> _handleSubmitQuiz() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) throw 'User not authenticated';

        final submissionData = {
          'courseId': widget.courseId,
          'quizId': widget.quizId,
          'studentId': user.uid,
          'studentName': _studentName ?? 'Unknown Student',
          'content': _submissionController.text.trim(),
          'submittedAt': FieldValue.serverTimestamp(),
        };

        if (widget.submissionId != null) {
          await _firestore
              .collection('courses')
              .doc(widget.courseId)
              .collection('quizSubmissions')
              .doc(widget.submissionId)
              .update(submissionData);
        } else {
          await _firestore
              .collection('courses')
              .doc(widget.courseId)
              .collection('quizSubmissions')
              .add(submissionData);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz submitted successfully!'),
              backgroundColor: kSuccessColor,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting quiz: $e'),
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
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.black87),
      maxLines: maxLines,
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
  void dispose() {
    _submissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.submissionId == null ? 'Submit Quiz' : 'Edit Submission'),
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.upload_file, size: 100, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      widget.quizData['title']?.trim() ?? 'Untitled Quiz',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.quizData['description']?.trim() ?? 'No description',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _submissionController,
                      label: 'Quiz Submission',
                      icon: Icons.description,
                      maxLines: 6,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your submission' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      onPressed: _isLoading ? null : _handleSubmitQuiz,
                      label: widget.submissionId == null ? 'Submit Quiz' : 'Update Submission',
                      isLoading: _isLoading,
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