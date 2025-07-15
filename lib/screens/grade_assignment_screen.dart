import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class GradeAssignmentScreen extends StatefulWidget {
  final String enrollmentId;
  final String assignmentId;
  final String courseId;
  final String studentName;
  final String submissionId;

  const GradeAssignmentScreen({
    super.key,
    required this.enrollmentId,
    required this.assignmentId,
    required this.courseId,
    required this.studentName,
    required this.submissionId,
  });

  @override
  _GradeAssignmentScreenState createState() => _GradeAssignmentScreenState();
}

class _GradeAssignmentScreenState extends State<GradeAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gradeController = TextEditingController();
  final _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  Map<String, dynamic>? _submissionData;

  @override
  void initState() {
    super.initState();
    print('GradeAssignmentScreen initialized with enrollmentId: ${widget.enrollmentId}, courseId: ${widget.courseId}, studentName: ${widget.studentName}, submissionId: ${widget.submissionId}'); // Debug log
    _fetchSubmissionData();
  }

  Future<void> _fetchSubmissionData() async {
    try {
      final submissionDoc = await _firestore
          .collection('courses')
          .doc(widget.courseId)
          .collection('submissions')
          .doc(widget.submissionId)
          .get();
      if (mounted && submissionDoc.exists) {
        setState(() {
          _submissionData = submissionDoc.data();
          _gradeController.text = _submissionData?['grade']?.toString() ?? '';
          _commentController.text = _submissionData?['comment']?.trim() ?? '';
        });
      } else {
        throw 'Submission document not found for submissionId: ${widget.submissionId}';
      }
    } catch (e) {
      print('Error fetching submission data: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading submission: $e'), backgroundColor: kErrorColor),
        );
      }
    }
  }

  Future<void> _handleSubmitGrade() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Log enrollment check
        print('Checking enrollment document: ${widget.enrollmentId}'); // Debug log
        final enrollmentDocRef = _firestore.collection('enrollments').doc(widget.enrollmentId);
        final enrollmentDoc = await enrollmentDocRef.get();
        if (!enrollmentDoc.exists) {
          print('Enrollment document not found, attempting to create for courseId: ${widget.courseId}, studentId: ${widget.enrollmentId.split('_').last}'); // Debug log
          final studentDoc = await _firestore.collection('users').doc(widget.enrollmentId.split('_').last).get();
          if (!studentDoc.exists) {
            throw 'Student document not found for studentId: ${widget.enrollmentId.split('_').last}';
          }
          final studentData = studentDoc.data() as Map<String, dynamic>;
          await enrollmentDocRef.set({
            'courseId': widget.courseId,
            'studentId': widget.enrollmentId.split('_').last,
            'studentName': studentData['name']?.trim() ?? 'Unknown Student',
            'enrolledAt': FieldValue.serverTimestamp(),
            'grades': {},
            'assignmentsSubmitted': [],
            'quizzesSubmitted': [],
          });
          print('Created enrollment document: ${widget.enrollmentId}'); // Debug log
        }

        // Update submission with grade and comment
        final submissionDocRef = _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('submissions')
            .doc(widget.submissionId);
        final batch = _firestore.batch();
        batch.update(submissionDocRef, {
          'grade': int.parse(_gradeController.text.trim()),
          'comment': _commentController.text.trim(),
          'gradedAt': FieldValue.serverTimestamp(),
        });

        // Update enrollment with grade and assignmentsSubmitted
        batch.update(enrollmentDocRef, {
          'grades.${widget.assignmentId}': int.parse(_gradeController.text.trim()),
          'assignmentsSubmitted': FieldValue.arrayUnion([widget.assignmentId]),
        });

        await batch.commit();
        print('Grade submitted for assignmentId: ${widget.assignmentId}, enrollmentId: ${widget.enrollmentId}'); // Debug log

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grade submitted successfully!'),
              backgroundColor: kSuccessColor,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        print('Error submitting grade: $e'); // Debug log
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting grade: $e'),
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
      keyboardType: label == 'Grade' ? TextInputType.number : TextInputType.text,
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
    _gradeController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Assignment'),
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
                    const Icon(Icons.grade, size: 100, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      'Grade for ${widget.studentName}',
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
                      _submissionData?['content']?.trim() ?? 'No submission content',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _gradeController,
                      label: 'Grade',
                      icon: Icons.score,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a grade';
                        final grade = int.tryParse(value);
                        if (grade == null || grade < 0 || grade > 100) return 'Enter a valid grade (0-100)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _commentController,
                      label: 'Comment',
                      icon: Icons.comment,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      onPressed: _isLoading ? null : _handleSubmitGrade,
                      label: 'Submit Grade',
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