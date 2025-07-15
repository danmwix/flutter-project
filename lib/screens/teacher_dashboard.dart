
import 'package:flutter/material.dart';
import 'package:jitsi_meet_wrapper/jitsi_meet_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'add_quiz_screen.dart';
import 'add_assignment_screen.dart';
import 'add_note_screen.dart';
import 'add_announcement_screen.dart';
import 'grade_assignment_screen.dart';
import 'grade_quiz_screen.dart';
import 'login_screen.dart';
import 'comments_screen.dart';
import 'enroll_student_screen.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  _AddCourseScreenState createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _languageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _addCourse() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _firestore.collection('courses').add({
          'title': _titleController.text.trim(),
          'language': _languageController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course added successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding course: $e'), backgroundColor: kErrorColor),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Course'),
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
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Course Title',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.book, color: kTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter a course title' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _languageController,
                    decoration: const InputDecoration(
                      labelText: 'Language',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.language, color: kTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Please enter a language' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addCourse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: kTextColor)
                        : const Text(
                            'Add Course',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
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

class TeacherDashboard extends StatefulWidget {
  final User? user;
  const TeacherDashboard({super.key, this.user});

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;
  String? _cachedName;

  @override
  void initState() {
    super.initState();
    _user = widget.user ?? _auth.currentUser;
    _cacheUserData();
    _auth.authStateChanges().listen((User? user) {
      if (!mounted) return;
      _updateUser();
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  Future<void> _cacheUserData() async {
    if (_user != null) {
      final teacherDoc = await _firestore.collection('teachers').doc(_user!.uid).get();
      if (mounted) {
        setState(() {
          _cachedName = teacherDoc.data()?['name']?.trim() ?? _user!.email?.split('@')[0] ?? 'Teacher';
        });
      }
    }
  }

  void _updateUser() {
    setState(() {
      _user = _auth.currentUser;
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldLogout == true && mounted) {
      await _auth.signOut();
      _updateUser();
    }
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
    IconData? icon,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const CircularProgressIndicator(color: kTextColor)
          : icon != null
              ? Icon(icon, color: kTextColor)
              : const SizedBox.shrink(),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: kPrimaryColor,
        elevation: 0,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle, size: 120, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Welcome, ${_cachedName ?? 'Teacher'}!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Manage courses, assignments, and quizzes',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildButton(
                  onPressed: _isLoading ? null : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddCourseScreen()),
                  ),
                  label: 'Add Course',
                  icon: Icons.add,
                ),
                const SizedBox(height: 16),
                _buildButton(
                  onPressed: _isLoading ? null : () => _viewCourses(),
                  label: 'View Courses',
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                _buildButton(
                  onPressed: _handleLogout,
                  label: 'Logout',
                  icon: Icons.exit_to_app,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewCourses() {
    if (_user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TeacherCoursesScreen(user: _user!, firestore: _firestore),
      ),
    );
  }
}

class _TeacherCoursesScreen extends StatelessWidget {
  final User user;
  final FirebaseFirestore firestore;

  const _TeacherCoursesScreen({required this.user, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('courses').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading courses', style: TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No courses found', style: TextStyle(color: Colors.white)));
            }
            final courses = snapshot.data!.docs.where((doc) => doc.exists).toList();
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final courseData = courses[index].data() as Map<String, dynamic>;
                final courseId = courses[index].id;
                return _TeacherCourseCard(
                  courseId: courseId,
                  courseData: courseData,
                  user: user,
                  firestore: firestore,
                  context: context,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TeacherCourseCard extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final User user;
  final FirebaseFirestore firestore;
  final BuildContext context;

  const _TeacherCourseCard({
    required this.courseId,
    required this.courseData,
    required this.user,
    required this.firestore,
    required this.context,
  });

  @override
  _TeacherCourseCardState createState() => _TeacherCourseCardState();
}

class _TeacherCourseCardState extends State<_TeacherCourseCard> {
  bool _isLoading = false;

  Future<void> _deleteCourse(String courseId) async {
    final shouldDelete = await showDialog<bool>(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this course? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await widget.firestore.collection('courses').doc(courseId).delete();
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Course deleted successfully!'), backgroundColor: kSuccessColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error deleting course: $e'), backgroundColor: kErrorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAssignment(String assignmentId) async {
    final shouldDelete = await showDialog<bool>(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this assignment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await widget.firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments')
            .doc(assignmentId)
            .delete();
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Assignment deleted successfully!'), backgroundColor: kSuccessColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error deleting assignment: $e'), backgroundColor: kErrorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteQuiz(String quizId) async {
    final shouldDelete = await showDialog<bool>(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this quiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await widget.firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('quizzes')
            .doc(quizId)
            .delete();
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Quiz deleted successfully!'), backgroundColor: kSuccessColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error deleting quiz: $e'), backgroundColor: kErrorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final shouldDelete = await showDialog<bool>(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await widget.firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('notes')
            .doc(noteId)
            .delete();
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully!'), backgroundColor: kSuccessColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e'), backgroundColor: kErrorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    final shouldDelete = await showDialog<bool>(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kErrorColor)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await widget.firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('announcements')
            .doc(announcementId)
            .delete();
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully!'), backgroundColor: kSuccessColor),
        );
      } catch (e) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error deleting announcement: $e'), backgroundColor: kErrorColor),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _awardBadge(String studentId, String courseId) async {
    try {
      final badgeRef = widget.firestore
          .collection('users')
          .doc(studentId)
          .collection('badges')
          .doc(courseId);
      final badgeDoc = await badgeRef.get();
      if (!badgeDoc.exists) {
        await badgeRef.set({
          'courseId': courseId,
          'awardedAt': FieldValue.serverTimestamp(),
          'badgeType': 'Course Completion',
        });
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Badge awarded successfully!'), backgroundColor: kSuccessColor),
        );
      } else {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Badge already awarded!'), backgroundColor: kErrorColor),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(widget.context).showSnackBar(
        SnackBar(content: Text('Error awarding badge: $e'), backgroundColor: kErrorColor),
      );
    }
  }

  Future<void> _scheduleMeeting() async {
    final selectedDate = await showDatePicker(
      context: widget.context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2025, 7, 16),
    );
    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: widget.context,
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
        ScaffoldMessenger.of(widget.context).showSnackBar(
          const SnackBar(content: Text('Please select a future time'), backgroundColor: kErrorColor),
        );
      }
      return;
    }

    final roomId = const Uuid().v4();
    setState(() => _isLoading = true);
    try {
      await widget.firestore
          .collection('courses')
          .doc(widget.courseId)
          .collection('meetings')
          .add({
        'roomId': roomId,
        'scheduledTime': scheduledTime,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Meeting scheduled for ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'), backgroundColor: kSuccessColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Error scheduling meeting: $e'), backgroundColor: kErrorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startMeeting(BuildContext context, String roomId, DateTime scheduledTime) async {
    if (DateTime.now().isBefore(scheduledTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meeting starts at ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'), backgroundColor: kErrorColor),
      );
      return;
    }

    var options = JitsiMeetingOptions(
      roomNameOrUrl: roomId,
      serverUrl: "https://meet.jit.si",
      subject: "Course Meeting - ${widget.courseData['title']}",
      userDisplayName: "Teacher_${widget.user.uid}",
      userEmail: "${widget.user.uid}@example.com",
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $error'), backgroundColor: kErrorColor),
              );
            }
            if (mounted) Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining meeting: $e'), backgroundColor: kErrorColor),
      );
    }
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
    IconData? icon,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const CircularProgressIndicator(color: kTextColor)
          : icon != null
              ? Icon(icon, color: kTextColor)
              : const SizedBox.shrink(),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          widget.courseData['title'] ?? 'Untitled Course',
          style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
        ),
        subtitle: Text('Language: ${widget.courseData['language'] ?? 'Unknown'}'),
        children: [
          ListTile(
            title: const Text('Enroll Student'),
            leading: const Icon(Icons.person_add, color: kTextColor),
            onTap: () => Navigator.push(
              widget.context,
              MaterialPageRoute(
                builder: (context) => EnrollStudentScreen(
                  courseId: widget.courseId,
                  courseTitle: widget.courseData['title'] ?? 'Untitled Course',
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Add Assignment'),
            leading: const Icon(Icons.add, color: kTextColor),
            onTap: () => Navigator.push(
              widget.context,
              MaterialPageRoute(
                builder: (context) => AddAssignmentScreen(courseId: widget.courseId),
              ),
            ),
          ),
          ListTile(
            title: const Text('Add Note'),
            leading: const Icon(Icons.add, color: kTextColor),
            onTap: () => Navigator.push(
              widget.context,
              MaterialPageRoute(
                builder: (context) => AddNoteScreen(courseId: widget.courseId),
              ),
            ),
          ),
          ListTile(
            title: const Text('Add Quiz'),
            leading: const Icon(Icons.add, color: kTextColor),
            onTap: () => Navigator.push(
              widget.context,
              MaterialPageRoute(
                builder: (context) => AddQuizScreen(courseId: widget.courseId),
              ),
            ),
          ),
          ListTile(
            title: const Text('Add Announcement'),
            leading: const Icon(Icons.add, color: kTextColor),
            onTap: () => Navigator.push(
              widget.context,
              MaterialPageRoute(
                builder: (context) => AddAnnouncementScreen(courseId: widget.courseId),
              ),
            ),
          ),
          ListTile(
            title: const Text('Schedule Meeting'),
            leading: const Icon(Icons.video_call, color: kTextColor),
            onTap: _scheduleMeeting,
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('courses')
                .doc(widget.courseId)
                .collection('meetings')
                .orderBy('scheduledTime', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading meetings...'));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final meeting = snapshot.data!.docs.first;
              final meetingData = meeting.data() as Map<String, dynamic>;
              final roomId = meetingData['roomId'] as String;
              final scheduledTime = (meetingData['scheduledTime'] as Timestamp).toDate();
              return ListTile(
                title: const Text('Join Scheduled Meeting'),
                leading: const Icon(Icons.video_call, color: kTextColor),
                onTap: () => _startMeeting(widget.context, roomId, scheduledTime),
                subtitle: Text('Scheduled for: ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'),
              );
            },
          ),
          ListTile(
            title: const Text('Delete Course'),
            leading: const Icon(Icons.delete, color: kErrorColor),
            onTap: () => _deleteCourse(widget.courseId),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Assignments', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('courses')
                .doc(widget.courseId)
                .collection('assignments')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading assignments...'));
              }
              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading assignments', style: TextStyle(color: kErrorColor)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const ListTile(title: Text('No assignments'));
              }
              final assignments = snapshot.data!.docs;
              return Column(
                children: assignments.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
                  return ExpansionTile(
                    title: Text(data['title'] ?? 'Untitled Assignment'),
                    subtitle: Text('Due: ${dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date'}'),
                    children: [
                      ListTile(
                        title: Text('Description: ${data['description'] ?? 'No description'}'),
                        subtitle: Text('Content: ${data['content'] ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('Grade Submissions'),
                        leading: const Icon(Icons.grade, color: kTextColor),
                        onTap: () => Navigator.push(
                          widget.context,
                          MaterialPageRoute(
                            builder: (context) => _GradeSubmissionsScreen(
                              courseId: widget.courseId,
                              assignmentId: doc.id,
                              firestore: widget.firestore,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          widget.context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: widget.courseId,
                              resourceId: doc.id,
                              resourceType: 'assignments',
                              resourceTitle: data['title'] ?? 'Untitled Assignment',
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('Delete Assignment'),
                        leading: const Icon(Icons.delete, color: kErrorColor),
                        onTap: () => _deleteAssignment(doc.id),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Quizzes', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('courses')
                .doc(widget.courseId)
                .collection('quizzes')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading quizzes...'));
              }
              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading quizzes', style: TextStyle(color: kErrorColor)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const ListTile(title: Text('No quizzes'));
              }
              final quizzes = snapshot.data!.docs;
              return Column(
                children: quizzes.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
                  return ExpansionTile(
                    title: Text(data['title'] ?? 'Untitled Quiz'),
                    subtitle: Text('Due: ${dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date'}'),
                    children: [
                      ListTile(
                        title: Text('Description: ${data['description'] ?? 'No description'}'),
                        subtitle: Text('Content: ${data['content'] ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('Grade Submissions'),
                        leading: const Icon(Icons.grade, color: kTextColor),
                        onTap: () => Navigator.push(
                          widget.context,
                          MaterialPageRoute(
                            builder: (context) => _GradeQuizSubmissionsScreen(
                              courseId: widget.courseId,
                              quizId: doc.id,
                              firestore: widget.firestore,
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          widget.context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: widget.courseId,
                              resourceId: doc.id,
                              resourceType: 'quizzes',
                              resourceTitle: data['title'] ?? 'Untitled Quiz',
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('Delete Quiz'),
                        leading: const Icon(Icons.delete, color: kErrorColor),
                        onTap: () => _deleteQuiz(doc.id),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('courses')
                .doc(widget.courseId)
                .collection('notes')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading notes...'));
              }
              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading notes', style: TextStyle(color: kErrorColor)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const ListTile(title: Text('No notes'));
              }
              final notes = snapshot.data!.docs;
              return Column(
                children: notes.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ExpansionTile(
                    title: Text(data['title'] ?? 'Untitled Note'),
                    children: [
                      ListTile(
                        title: Text('Content: ${data['content'] ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          widget.context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: widget.courseId,
                              resourceId: doc.id,
                              resourceType: 'notes',
                              resourceTitle: data['title'] ?? 'Untitled Note',
                            ),
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('Delete Note'),
                        leading: const Icon(Icons.delete, color: kErrorColor),
                        onTap: () => _deleteNote(doc.id),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('courses')
                .doc(widget.courseId)
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading announcements...'));
              }
              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading announcements', style: TextStyle(color: kErrorColor)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const ListTile(title: Text('No announcements'));
              }
              final announcements = snapshot.data!.docs;
              return Column(
                children: announcements.map<Widget>((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  return ExpansionTile(
                    title: Text(data['message'] ?? 'Untitled Announcement'),
                    subtitle: Text(timestamp != null ? DateFormat('MMM d, yyyy').format(timestamp) : 'No date'),
                    children: [
                      ListTile(
                        title: Text('Message: ${data['message'] ?? 'No message'}'),
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: widget.firestore
                            .collection('courses')
                            .doc(widget.courseId)
                            .collection('announcements')
                            .doc(doc.id)
                            .collection('comments')
                            .snapshots(),
                        builder: (context, commentSnapshot) {
                          if (commentSnapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(title: Text('Loading comments...'));
                          }
                          if (commentSnapshot.hasError) {
                            return const ListTile(
                              title: Text('Error loading comments', style: TextStyle(color: kErrorColor)),
                            );
                          }
                          if (!commentSnapshot.hasData || commentSnapshot.data!.docs.isEmpty) {
                            return const ListTile(title: Text('No comments'));
                          }
                          return ListTile(
                            title: const Text('View Comments'),
                            leading: const Icon(Icons.comment, color: kTextColor),
                            onTap: () => Navigator.push(
                              widget.context,
                              MaterialPageRoute(
                                builder: (context) => CommentsScreen(
                                  courseId: widget.courseId,
                                  resourceId: doc.id,
                                  resourceType: 'announcements',
                                  resourceTitle: data['message'] != null && data['message'].toString().isNotEmpty
                                      ? data['message'].toString().length > 20
                                          ? data['message'].toString().substring(0, 20).trim()
                                          : data['message'].toString().trim()
                                      : 'Untitled Announcement',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Delete Announcement'),
                        leading: const Icon(Icons.delete, color: kErrorColor),
                        onTap: () => _deleteAnnouncement(doc.id),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GradeSubmissionsScreen extends StatelessWidget {
  final String courseId;
  final String assignmentId;
  final FirebaseFirestore firestore;

  const _GradeSubmissionsScreen({
    required this.courseId,
    required this.assignmentId,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Assignment Submissions'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('courses')
              .doc(courseId)
              .collection('submissions')
              .where('assignmentId', isEqualTo: assignmentId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading submissions', style: TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No submissions found', style: TextStyle(color: Colors.white)));
            }
            final submissions = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final submissionData = submission.data() as Map<String, dynamic>;
                final studentId = submissionData['studentId'];
                print('Processing submission for studentId: $studentId, courseId: $courseId, enrollmentId: ${courseId}_$studentId');
                return FutureBuilder<DocumentSnapshot>(
                  future: firestore.collection('users').doc(studentId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const ListTile(title: Text('Loading student...'));
                    }
                    final studentData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final studentName = studentData['name']?.trim() ?? 'Unknown Student';
                    final enrollmentId = '${courseId}_$studentId';
                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore.collection('enrollments').doc(enrollmentId).get(),
                      builder: (context, enrollmentSnapshot) {
                        if (!enrollmentSnapshot.hasData) {
                          return const ListTile(title: Text('Checking enrollment...'));
                        }
                        if (!enrollmentSnapshot.data!.exists) {
                          print('Enrollment not found for $enrollmentId');
                          return ListTile(
                            title: Text('Submission by $studentName'),
                            subtitle: const Text('Enrollment not found'),
                            enabled: false,
                          );
                        }
                        return ListTile(
                          title: Text('Submission by $studentName'),
                          subtitle: Text(submissionData['grade'] != null
                              ? 'Graded: ${submissionData['grade']}/100'
                              : 'Not graded'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GradeAssignmentScreen(
                                enrollmentId: enrollmentId,
                                assignmentId: assignmentId,
                                courseId: courseId,
                                studentName: studentName,
                                submissionId: submission.id,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GradeQuizSubmissionsScreen extends StatelessWidget {
  final String courseId;
  final String quizId;
  final FirebaseFirestore firestore;

  const _GradeQuizSubmissionsScreen({
    required this.courseId,
    required this.quizId,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Quiz Submissions'),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('courses')
              .doc(courseId)
              .collection('quizSubmissions')
              .where('quizId', isEqualTo: quizId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading submissions', style: TextStyle(color: Colors.white)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No submissions found', style: TextStyle(color: Colors.white)));
            }
            final submissions = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final submissionData = submission.data() as Map<String, dynamic>;
                final studentId = submissionData['studentId'];
                print('Processing quiz submission for studentId: $studentId, courseId: $courseId, enrollmentId: ${courseId}_$studentId');
                return FutureBuilder<DocumentSnapshot>(
                  future: firestore.collection('users').doc(studentId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const ListTile(title: Text('Loading student...'));
                    }
                    final studentData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final studentName = studentData['name']?.trim() ?? 'Unknown Student';
                    final enrollmentId = '${courseId}_$studentId';
                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore.collection('enrollments').doc(enrollmentId).get(),
                      builder: (context, enrollmentSnapshot) {
                        if (!enrollmentSnapshot.hasData) {
                          return const ListTile(title: Text('Checking enrollment...'));
                        }
                        if (!enrollmentSnapshot.data!.exists) {
                          print('Enrollment not found for $enrollmentId');
                          return ListTile(
                            title: Text('Submission by $studentName'),
                            subtitle: const Text('Enrollment not found'),
                            enabled: false,
                          );
                        }
                        return ListTile(
                          title: Text('Submission by $studentName'),
                          subtitle: Text(submissionData['grade'] != null
                              ? 'Graded: ${submissionData['grade']}/100'
                              : 'Not graded'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GradeQuizScreen(
                                enrollmentId: enrollmentId,
                                quizId: quizId,
                                courseId: courseId,
                                studentName: studentName,
                                submissionId: submission.id,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
