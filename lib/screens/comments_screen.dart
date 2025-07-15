import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class CommentsScreen extends StatefulWidget {
  final String courseId;
  final String resourceId; // assignmentId, quizId, noteId, or announcementId
  final String resourceType; // 'assignments', 'quizzes', 'notes', or 'announcements'
  final String resourceTitle;

  const CommentsScreen({
    super.key,
    required this.courseId,
    required this.resourceId,
    required this.resourceType,
    required this.resourceTitle,
  });

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isTeacher = false;
  String? _cachedDisplayName;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _cachedDisplayName = userDoc.data()?['displayName']?.trim() ?? user.email?.split('@')[0] ?? 'User';
          _isTeacher = userDoc.data()?['role'] == 'teacher';
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) throw 'User not authenticated';
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection(widget.resourceType)
            .doc(widget.resourceId)
            .collection('comments')
            .add({
          'userId': user.uid,
          'userName': _cachedDisplayName ?? user.email?.split('@')[0] ?? 'User',
          'content': _commentController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        _commentController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment posted successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error posting comment: $e'), backgroundColor: kErrorColor),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _postReply(String commentId) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = _auth.currentUser;
        if (user == null) throw 'User not authenticated';
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection(widget.resourceType)
            .doc(widget.resourceId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .add({
          'userId': user.uid,
          'userName': _cachedDisplayName ?? user.email?.split('@')[0] ?? 'User',
          'content': _replyController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'parentCommentId': commentId,
        });
        _replyController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply posted successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error posting reply: $e'), backgroundColor: kErrorColor),
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
      keyboardType: maxLines == 1 ? TextInputType.text : TextInputType.multiline,
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
        title: Text('Comments - ${widget.resourceTitle}'),
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
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('courses')
                      .doc(widget.courseId)
                      .collection(widget.resourceType)
                      .doc(widget.resourceId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading comments', style: TextStyle(color: kErrorColor)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No comments', style: TextStyle(color: Colors.white)));
                    }
                    final comments = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        final commentId = comments[index].id;
                        final timestamp = (comment['timestamp'] as Timestamp?)?.toDate();
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ExpansionTile(
                            title: Text(
                              comment['content'] ?? 'No content',
                              style: const TextStyle(color: kTextColor),
                            ),
                            subtitle: Text(
                              'By ${comment['userName']} on ${timestamp != null ? DateFormat('MMM d, yyyy, h:mm a').format(timestamp) : 'Unknown time'}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            children: [
                              // Replies
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('courses')
                                    .doc(widget.courseId)
                                    .collection(widget.resourceType)
                                    .doc(widget.resourceId)
                                    .collection('comments')
                                    .doc(commentId)
                                    .collection('replies')
                                    .orderBy('timestamp', descending: true)
                                    .snapshots(),
                                builder: (context, replySnapshot) {
                                  if (replySnapshot.connectionState == ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: kTextColor),
                                    );
                                  }
                                  if (replySnapshot.hasError) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Error loading replies', style: TextStyle(color: kErrorColor)),
                                    );
                                  }
                                  if (!replySnapshot.hasData || replySnapshot.data!.docs.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('No replies', style: TextStyle(color: kTextColor)),
                                    );
                                  }
                                  final replies = replySnapshot.data!.docs;
                                  return Column(
                                    children: replies.map<Widget>((replyDoc) {
                                      final reply = replyDoc.data() as Map<String, dynamic>;
                                      final replyTimestamp = (reply['timestamp'] as Timestamp?)?.toDate();
                                      return ListTile(
                                        contentPadding: const EdgeInsets.only(left: 32.0, right: 16.0),
                                        title: Text(
                                          reply['content'] ?? 'No content',
                                          style: const TextStyle(color: kTextColor),
                                        ),
                                        subtitle: Text(
                                          'Reply by ${reply['userName']} on ${replyTimestamp != null ? DateFormat('MMM d, yyyy, h:mm a').format(replyTimestamp) : 'Unknown time'}',
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              // Reply input for teachers
                              if (_isTeacher)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildTextField(
                                        controller: _replyController,
                                        label: 'Reply to comment',
                                        icon: Icons.reply,
                                        maxLines: 3,
                                        validator: (value) => value == null || value.isEmpty ? 'Please enter a reply' : null,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildButton(
                                        onPressed: _isLoading ? null : () => _postReply(commentId),
                                        label: 'Post Reply',
                                        isLoading: _isLoading,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _commentController,
                        label: 'Add a comment',
                        icon: Icons.comment,
                        maxLines: 3,
                        validator: (value) => value == null || value.isEmpty ? 'Please enter a comment' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildButton(
                        onPressed: _isLoading ? null : _postComment,
                        label: 'Post Comment',
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}