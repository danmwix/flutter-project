
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jitsi_meet_wrapper/jitsi_meet_wrapper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'add_course_screen.dart';
import 'add_assignment_screen.dart';
import 'grade_assignment_screen.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  _CourseDetailScreenState createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _enrollFormKey = GlobalKey<FormState>();
  final _admissionNumberController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleEnrollStudent() async {
    if (_enrollFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final admissionNumber = _admissionNumberController.text.trim().toUpperCase();
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('admissionNumber', isEqualTo: admissionNumber)
            .where('role', isEqualTo: 'student')
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final studentId = userQuery.docs.first.id;
          final studentData = userQuery.docs.first.data() as Map<String, dynamic>;
          final studentName = studentData['name']?.trim() ?? 'Unknown Student';
          final enrollmentId = '${widget.courseId}_$studentId';
          final enrollmentQuery = await FirebaseFirestore.instance
              .collection('enrollments')
              .doc(enrollmentId)
              .get();

          if (enrollmentQuery.exists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Student $studentName is already enrolled'),
                  backgroundColor: kErrorColor,
                ),
              );
            }
          } else {
            await FirebaseFirestore.instance.collection('enrollments').doc(enrollmentId).set({
              'courseId': widget.courseId,
              'studentId': studentId,
              'studentName': studentName,
              'enrolledAt': FieldValue.serverTimestamp(),
              'grades': {},
              'assignmentsSubmitted': [],
              'quizzesSubmitted': [],
            });
            if (mounted) {
              _admissionNumberController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Student enrolled successfully!'),
                  backgroundColor: kSuccessColor,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No student found with this admission number'),
                backgroundColor: kErrorColor,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error enrolling student: $e'),
              backgroundColor: kErrorColor,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showStudentsForGrading(String assignmentId, String assignmentTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('enrollments')
            .where('courseId', isEqualTo: widget.courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kTextColor));
          }
          final enrollments = snapshot.data!.docs;
          if (enrollments.isEmpty) {
            return const Center(child: Text('No students enrolled', style: TextStyle(color: Colors.black87)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: enrollments.length,
            itemBuilder: (context, index) {
              final enrollment = enrollments[index];
              final studentId = enrollment['studentId'];
              final studentName = enrollment['studentName']?.trim() ?? 'Unknown Student';
              final enrollmentId = enrollment.id;
              return FutureBuilder<DocumentSnapshot?>(
                future: FirebaseFirestore.instance
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('submissions')
                    .where('studentId', isEqualTo: studentId)
                    .where('assignmentId', isEqualTo: assignmentId)
                    .limit(1)
                    .get()
                    .then((querySnapshot) => querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null),
                builder: (context, submissionSnapshot) {
                  if (!submissionSnapshot.hasData) {
                    return const ListTile(title: Text('Loading...', style: TextStyle(color: Colors.black87)));
                  }
                  final submissionDoc = submissionSnapshot.data;
                  final submissionId = submissionDoc?.id;
                  return ListTile(
                    title: Text(studentName, style: const TextStyle(color: Colors.black87)),
                    trailing: const Icon(Icons.arrow_forward, color: kTextColor),
                    onTap: submissionId != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GradeAssignmentScreen(
                                  enrollmentId: enrollmentId,
                                  assignmentId: assignmentId,
                                  courseId: widget.courseId,
                                  studentName: studentName,
                                  submissionId: submissionId,
                                ),
                              ),
                            )
                        : null,
                    enabled: submissionId != null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _scheduleMeeting() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2025, 7, 16), // Capped to one day before expiration
    );
    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))),
    );
    if (selectedTime == null) return;

    final scheduledTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (scheduledTime.isBefore(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a future time'), backgroundColor: kErrorColor),
        );
      }
      return;
    }

    final roomId = const Uuid().v4();
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings')
          .add({
        'roomId': roomId,
        'scheduledTime': scheduledTime,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting scheduled for ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'),
            backgroundColor: kSuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scheduling meeting: $e'), backgroundColor: kErrorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startMeeting(String roomId, DateTime scheduledTime) async {
    if (DateTime.now().isBefore(scheduledTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting starts at ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'),
            backgroundColor: kErrorColor,
          ),
        );
      }
      return;
    }

    var options = JitsiMeetingOptions(
      roomNameOrUrl: roomId,
      serverUrl: "https://meet.jit.si",
      subject: "Course Meeting - ${widget.courseId}",
      userDisplayName: "Teacher_${DateTime.now().millisecondsSinceEpoch}",
      userEmail: "teacher@example.com",
      isAudioMuted: false,
      isVideoMuted: false,
      configOverrides: {
        "startWithAudioMuted": false,
        "startWithVideoMuted": false,
        "prejoinPageEnabled": false, // Disable prejoin page
        "disableJoiningWithPassword": true, // Disable passcode prompt
      },
      featureFlags: {
        "welcomePageEnabled": false,
        "prejoinPageEnabled": false,
        "callIntegration": true,
        "securityOptions": {
          "requirePasscode": false, // Ensure no passcode is required
        },
      },
    );

    try {
      await JitsiMeetWrapper.joinMeeting(
        options: options,
        listener: JitsiMeetingListener(
          onConferenceWillJoin: (url) => debugPrint("Conference will join: $url"),
          onConferenceJoined: (url) => debugPrint("Conference joined: $url"),
          onConferenceTerminated: (url, error) {
            debugPrint("Conference terminated: $url, error: $error");
            if (error != null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $error'), backgroundColor: kErrorColor),
                );
              }
            }
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining meeting: $e'), backgroundColor: kErrorColor),
        );
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
      keyboardType: TextInputType.text,
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
  void dispose() {
    _admissionNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Course Details'),
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
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('courses').doc(widget.courseId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Course not found', style: TextStyle(color: kErrorColor)));
                }
                final course = snapshot.data!.data() as Map<String, dynamic>;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.book, size: 100, color: Colors.white),
                      const SizedBox(height: 24),
                      Text(
                        course['title']?.trim() ?? 'Untitled Course',
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
                        course['description']?.trim() ?? 'No description',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Language: ${course['language']?.trim() ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _enrollFormKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _admissionNumberController,
                                label: 'Student Admission Number',
                                icon: Icons.person,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter admission number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleEnrollStudent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: kTextColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: kTextColor)
                                  : const Text('Enroll'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddCourseScreen(
                              courseId: widget.courseId,
                              courseData: course,
                            ),
                          ),
                        ),
                        label: 'Edit Course',
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddAssignmentScreen(courseId: widget.courseId),
                          ),
                        ),
                        label: 'Add Assignment',
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        onPressed: _scheduleMeeting,
                        label: 'Schedule Meeting',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Assignments',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('assignments')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          final assignments = snapshot.data!.docs;
                          if (assignments.isEmpty) {
                            return const Center(child: Text('No assignments found', style: TextStyle(color: Colors.white)));
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: assignments.length,
                            itemBuilder: (context, index) {
                              final assignment = assignments[index];
                              final assignmentData = assignment.data() as Map<String, dynamic>;
                              final dueDate = (assignmentData['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                              if (dueDate.isAfter(DateTime(2025, 7, 16))) {
                                return const SizedBox.shrink(); // Skip assignments due after rules expire
                              }
                              return Card(
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    assignmentData['title']?.trim() ?? 'Untitled Assignment',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
                                  ),
                                  subtitle: Text('Due: ${dueDate.toString().substring(0, 10)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: kTextColor),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddAssignmentScreen(
                                              courseId: widget.courseId,
                                              assignmentId: assignment.id,
                                              assignmentData: assignmentData,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.grade, color: kSuccessColor),
                                        onPressed: () => _showStudentsForGrading(assignment.id, assignmentData['title']?.trim() ?? 'Untitled Assignment'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Meetings',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('meetings')
                            .orderBy('scheduledTime', descending: true)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No meetings scheduled', style: TextStyle(color: Colors.white)));
                          }
                          final meeting = snapshot.data!.docs.first;
                          final meetingData = meeting.data() as Map<String, dynamic>;
                          final roomId = meetingData['roomId'] as String;
                          final scheduledTime = (meetingData['scheduledTime'] as Timestamp).toDate();
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: const Text('Join Meeting'),
                              leading: const Icon(Icons.video_call, color: kTextColor),
                              subtitle: Text('Scheduled for: ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'),
                              onTap: () => _startMeeting(roomId, scheduledTime),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
