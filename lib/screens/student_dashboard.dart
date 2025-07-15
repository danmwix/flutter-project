
import 'package:flutter/material.dart';
import 'package:jitsi_meet_wrapper/jitsi_meet_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'submit_assignment_screen.dart';
import 'submit_quiz_screen.dart';
import 'comments_screen.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class StudentDashboard extends StatefulWidget {
  final User? user;
  const StudentDashboard({super.key, this.user});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
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
      setState(() => _user = user);
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
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      if (mounted) {
        setState(() {
          _cachedName = userDoc.data()?['name']?.trim() ?? _user!.email?.split('@')[0] ?? 'Student';
        });
      }
    }
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
      setState(() => _user = null);
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
        title: const Text('Student Dashboard'),
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
                  'Welcome, ${_cachedName ?? 'Student'}!',
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
                  'Explore your courses and assignments',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildButton(
                  onPressed: _isLoading ? null : () => _viewCourses(),
                  label: 'View Courses',
                  isLoading: _isLoading,
                  icon: Icons.book,
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
        builder: (context) => _StudentCoursesScreen(user: _user!, firestore: _firestore),
      ),
    );
  }
}

class _StudentCoursesScreen extends StatelessWidget {
  final User user;
  final FirebaseFirestore firestore;

  const _StudentCoursesScreen({required this.user, required this.firestore});

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
          stream: firestore
              .collection('enrollments')
              .where('studentId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Error loading enrollments', style: TextStyle(color: kErrorColor)),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('No courses enrolled', style: TextStyle(color: Colors.white)),
              );
            }
            final enrollments = snapshot.data!.docs;
            final uniqueCourseIds = <String>{};
            for (final doc in enrollments) {
              final courseId = (doc.data() as Map<String, dynamic>)['courseId'];
              if (courseId != null) uniqueCourseIds.add(courseId);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: uniqueCourseIds.length,
              itemBuilder: (context, index) {
                final courseId = uniqueCourseIds.elementAt(index);
                return FutureBuilder<DocumentSnapshot>(
                  future: firestore.collection('courses').doc(courseId).get(),
                  builder: (context, courseSnapshot) {
                    if (courseSnapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Text('Loading course...'));
                    }
                    if (!courseSnapshot.hasData || !courseSnapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final courseData = courseSnapshot.data!.data() as Map<String, dynamic>;
                    return _StudentCourseCard(
                      courseId: courseId,
                      courseData: courseData,
                      user: user,
                      firestore: firestore,
                      context: context,
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

class _StudentCourseCard extends StatelessWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  final User user;
  final FirebaseFirestore firestore;
  final BuildContext context;

  const _StudentCourseCard({
    required this.courseId,
    required this.courseData,
    required this.user,
    required this.firestore,
    required this.context,
  });

  Future<void> _joinMeeting(BuildContext context, String roomId, DateTime scheduledTime) async {
    if (DateTime.now().isBefore(scheduledTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meeting starts at ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'), backgroundColor: kErrorColor),
      );
      return;
    }

    var options = JitsiMeetingOptions(
      roomNameOrUrl: roomId,
      serverUrl: "https://meet.jit.si",
      subject: "Course Meeting - ${courseData['title']}",
      userDisplayName: "Student_${user.uid}",
      userEmail: "${user.uid}@example.com",
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error'), backgroundColor: kErrorColor));
            }
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining meeting: $e'), backgroundColor: kErrorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentId = '${courseId}_${user.uid}';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          courseData['title']?.trim() ?? 'Untitled Course',
          style: const TextStyle(fontWeight: FontWeight.bold, color: kTextColor),
        ),
        subtitle: Text('Language: ${courseData['language']?.trim() ?? 'Unknown'}'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text('Grades', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: firestore.collection('enrollments').doc(enrollmentId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading grades...'));
              }
              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading grades', style: TextStyle(color: kErrorColor)));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const ListTile(title: Text('No grades available'));
              }
              final enrollmentData = snapshot.data!.data() as Map<String, dynamic>;
              final grades = enrollmentData['grades'] as Map<String, dynamic>? ?? {};
              final quizzesSubmitted = enrollmentData['quizzesSubmitted'] as List<dynamic>? ?? [];
              final assignmentsSubmitted = enrollmentData['assignmentsSubmitted'] as List<dynamic>? ?? [];
              return Column(
                children: [
                  if (grades.isEmpty)
                    const ListTile(title: Text('No grades available')),
                  ...grades.entries.map<Widget>((entry) {
                    final itemId = entry.key;
                    final isQuiz = quizzesSubmitted.contains(itemId);
                    final isAssignment = assignmentsSubmitted.contains(itemId);
                    final gradeData = entry.value;
                    return FutureBuilder<DocumentSnapshot>(
                      future: firestore
                          .collection('courses')
                          .doc(courseId)
                          .collection(isQuiz ? 'quizzes' : 'assignments')
                          .doc(itemId)
                          .get(),
                      builder: (context, itemSnapshot) {
                        if (!itemSnapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }
                        final itemData = itemSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                        final title = itemData['title']?.trim() ?? (isQuiz ? 'Untitled Quiz' : 'Untitled Assignment');
                        return ListTile(
                          title: Text('$title (${isQuiz ? 'Quiz' : 'Assignment'})'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Grade: ${gradeData is int ? gradeData : gradeData['value'] ?? 'Not graded'}'),
                              if (isQuiz && gradeData['feedback'] != null)
                                Text('Feedback: ${gradeData['feedback']?.trim() ?? ''}'),
                              if (isQuiz && gradeData['badge'] == true)
                                const Text('Badge Awarded', style: TextStyle(color: kSuccessColor)),
                              if (!isQuiz)
                                FutureBuilder<QuerySnapshot>(
                                  future: firestore
                                      .collection('courses')
                                      .doc(courseId)
                                      .collection('submissions')
                                      .where('assignmentId', isEqualTo: itemId)
                                      .where('studentId', isEqualTo: user.uid)
                                      .limit(1)
                                      .get(),
                                  builder: (context, submissionSnapshot) {
                                    if (!submissionSnapshot.hasData) {
                                      return const Text('Loading comment...');
                                    }
                                    final submissionData = submissionSnapshot.hasData && submissionSnapshot.data!.docs.isNotEmpty
                                        ? submissionSnapshot.data!.docs.first.data() as Map<String, dynamic>
                                        : {};
                                    return Text('Comment: ${submissionData['comment']?.trim() ?? 'No comment'}');
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text('Assignments', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('courses')
                .doc(courseId)
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
                    title: Text(data['title']?.trim() ?? 'Untitled Assignment'),
                    subtitle: Text(
                      'Due: ${dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date'}',
                    ),
                    children: [
                      ListTile(
                        title: Text('Description: ${data['description']?.trim() ?? 'No description'}'),
                        subtitle: Text('Content: ${data['content']?.trim() ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('Submit Assignment'),
                        leading: const Icon(Icons.upload_file, color: kTextColor),
                        onTap: () async {
                          final submissionSnapshot = await firestore
                              .collection('courses')
                              .doc(courseId)
                              .collection('submissions')
                              .where('assignmentId', isEqualTo: doc.id)
                              .where('studentId', isEqualTo: user.uid)
                              .limit(1)
                              .get();
                          final submissionId = submissionSnapshot.docs.isNotEmpty ? submissionSnapshot.docs.first.id : null;
                          final submissionData = submissionSnapshot.docs.isNotEmpty
                              ? submissionSnapshot.docs.first.data() as Map<String, dynamic>
                              : null;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubmitAssignmentScreen(
                                courseId: courseId,
                                assignmentId: doc.id,
                                assignmentData: data,
                                submissionId: submissionId,
                                submissionData: submissionData,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: courseId,
                              resourceId: doc.id,
                              resourceType: 'assignments',
                              resourceTitle: data['title']?.trim() ?? 'Untitled Assignment',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text('Quizzes', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('courses')
                .doc(courseId)
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
                    title: Text(data['title']?.trim() ?? 'Untitled Quiz'),
                    subtitle: Text(
                      'Due: ${dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate) : 'No due date'}',
                    ),
                    children: [
                      ListTile(
                        title: Text('Description: ${data['description']?.trim() ?? 'No description'}'),
                        subtitle: Text('Content: ${data['content']?.trim() ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('Submit Quiz'),
                        leading: const Icon(Icons.upload_file, color: kTextColor),
                        onTap: () async {
                          final submissionSnapshot = await firestore
                              .collection('courses')
                              .doc(courseId)
                              .collection('quizSubmissions')
                              .where('quizId', isEqualTo: doc.id)
                              .where('studentId', isEqualTo: user.uid)
                              .limit(1)
                              .get();
                          final submissionId = submissionSnapshot.docs.isNotEmpty ? submissionSnapshot.docs.first.id : null;
                          final submissionData = submissionSnapshot.docs.isNotEmpty
                              ? submissionSnapshot.docs.first.data() as Map<String, dynamic>
                              : null;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubmitQuizScreen(
                                courseId: courseId,
                                quizId: doc.id,
                                quizData: data,
                                submissionId: submissionId,
                                submissionData: submissionData,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: courseId,
                              resourceId: doc.id,
                              resourceType: 'quizzes',
                              resourceTitle: data['title']?.trim() ?? 'Untitled Quiz',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('courses')
                .doc(courseId)
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
                    title: Text(data['title']?.trim() ?? 'Untitled Note'),
                    children: [
                      ListTile(
                        title: Text('Content: ${data['content']?.trim() ?? 'No content'}'),
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: courseId,
                              resourceId: doc.id,
                              resourceType: 'notes',
                              resourceTitle: data['title']?.trim() ?? 'Untitled Note',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, color: kTextColor)),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('courses')
                .doc(courseId)
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
                    title: Text(data['message']?.trim() ?? 'Untitled Announcement'),
                    subtitle: Text(
                      timestamp != null ? DateFormat('MMM d, yyyy').format(timestamp) : 'No date',
                    ),
                    children: [
                      ListTile(
                        title: Text('Message: ${data['message']?.trim() ?? 'No message'}'),
                      ),
                      ListTile(
                        title: const Text('View Comments'),
                        leading: const Icon(Icons.comment, color: kTextColor),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentsScreen(
                              courseId: courseId,
                              resourceId: doc.id,
                              resourceType: 'announcements',
                              resourceTitle: data['message']?.substring(0, data['message'].length > 20 ? 20 : data['message'].length)?.trim() ?? 'Untitled Announcement',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('courses')
                .doc(courseId)
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
                title: const Text('Join Meeting'),
                leading: const Icon(Icons.video_call, color: kTextColor),
                onTap: () => _joinMeeting(context, roomId, scheduledTime),
                subtitle: Text('Scheduled for: ${DateFormat('yyyy-MM-dd HH:mm').format(scheduledTime)}'),
              );
            },
          ),
        ],
      ),
    );
  }
}
