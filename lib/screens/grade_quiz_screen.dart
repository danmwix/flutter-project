import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class GradeQuizScreen extends StatefulWidget {
  final String enrollmentId;
  final String quizId;
  final String courseId;
  final String studentName;
  final String submissionId;

  const GradeQuizScreen({
    super.key,
    required this.enrollmentId,
    required this.quizId,
    required this.courseId,
    required this.studentName,
    required this.submissionId,
  });

  @override
  _GradeQuizScreenState createState() => _GradeQuizScreenState();
}

class _GradeQuizScreenState extends State<GradeQuizScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gradeController = TextEditingController();
  final _feedbackController = TextEditingController();
  bool _awardBadge = false;
  bool _isLoading = false;
  String? _quizTitle;
  String? _submissionResponse;

  @override
  void initState() {
    super.initState();
    print('GradeQuizScreen initialized with enrollmentId: ${widget.enrollmentId}, courseId: ${widget.courseId}, studentName: ${widget.studentName}, submissionId: ${widget.submissionId}'); // Debug log
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final quizDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
      if (quizDoc.exists && mounted) {
        setState(() {
          _quizTitle = quizDoc.data()?['title'] ?? 'Untitled Quiz';
        });
      }

      final submissionDoc = await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('quizSubmissions')
          .doc(widget.submissionId)
          .get();
      if (submissionDoc.exists && mounted) {
        final data = submissionDoc.data() as Map<String, dynamic>;
        setState(() {
          _submissionResponse = data['response'];
          _gradeController.text = data['grade']?.toString() ?? '';
          _feedbackController.text = data['feedback'] ?? '';
          _awardBadge = data['badge'] ?? false;
        });
      } else {
        throw 'Submission document not found for submissionId: ${widget.submissionId}';
      }
    } catch (e) {
      print('Error loading quiz data: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: kErrorColor),
        );
      }
    }
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _handleGradeQuiz() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final batch = FirebaseFirestore.instance.batch();
        final submissionDocRef = FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('quizSubmissions')
            .doc(widget.submissionId);
        final enrollmentDocRef = FirebaseFirestore.instance.collection('enrollments').doc(widget.enrollmentId);

        // Log enrollment check
        print('Checking enrollment document: ${widget.enrollmentId}'); // Debug log
        final enrollmentDoc = await enrollmentDocRef.get();
        if (!enrollmentDoc.exists) {
          print('Enrollment document not found, attempting to create for courseId: ${widget.courseId}, studentId: ${widget.enrollmentId.split('_').last}'); // Debug log
          final studentDoc = await FirebaseFirestore.instance.collection('users').doc(widget.enrollmentId.split('_').last).get();
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

        final gradeData = {
          'grade': int.parse(_gradeController.text.trim()),
          'marked': true,
          'feedback': _feedbackController.text.trim(),
          'badge': _awardBadge,
          'gradedAt': FieldValue.serverTimestamp(),
        };

        // Update badge in user's badges collection if awarded
        if (_awardBadge) {
          final badgeRef = FirebaseFirestore.instance
              .collection('users')
              .doc(widget.enrollmentId.split('_').last)
              .collection('badges')
              .doc(widget.courseId);
          batch.set(badgeRef, {
            'courseId': widget.courseId,
            'awardedAt': FieldValue.serverTimestamp(),
            'badgeType': 'Quiz Completion',
          });
        }

        batch.update(submissionDocRef, gradeData);
        batch.update(enrollmentDocRef, {
          'grades.${widget.quizId}': {
            'value': int.parse(_gradeController.text.trim()),
            'feedback': _feedbackController.text.trim(),
            'badge': _awardBadge,
            'gradedAt': FieldValue.serverTimestamp(),
          },
          'quizzesSubmitted': FieldValue.arrayUnion([widget.quizId]),
        });

        await batch.commit();
        print('Grade and badge submitted for quizId: ${widget.quizId}, enrollmentId: ${widget.enrollmentId}'); // Debug log

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grade submitted successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        print('Error submitting grade: $e'); // Debug log
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting grade: $e'), backgroundColor: kErrorColor),
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
      keyboardType: maxLines == 1 ? TextInputType.number : TextInputType.multiline,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        title: Text('Grade Quiz for ${widget.studentName}'),
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
                      'Grade Quiz: ${_quizTitle ?? 'Loading...'}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_submissionResponse != null) ...[
                      Text(
                        'Student Submission:',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _submissionResponse!,
                          style: const TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _gradeController,
                      label: 'Grade (0-100)',
                      icon: Icons.score,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a grade';
                        final grade = int.tryParse(value);
                        if (grade == null || grade < 0 || grade > 100) return 'Grade must be between 0 and 100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _feedbackController,
                      label: 'Feedback (Optional)',
                      icon: Icons.comment,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Award Badge', style: TextStyle(color: Colors.white)),
                      value: _awardBadge,
                      onChanged: (value) => setState(() => _awardBadge = value!),
                      checkColor: Colors.white,
                      activeColor: kTextColor,
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      onPressed: _isLoading || _submissionResponse == null ? null : _handleGradeQuiz,
                      label: 'Submit Grade',
                      isLoading: _isLoading,
                    ),
                    if (_submissionResponse == null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'No submission found for this quiz.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
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