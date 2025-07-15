import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class AddAnnouncementScreen extends StatefulWidget {
  final String courseId;

  const AddAnnouncementScreen({super.key, required this.courseId});

  @override
  _AddAnnouncementScreenState createState() => _AddAnnouncementScreenState();
}

class _AddAnnouncementScreenState extends State<AddAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _addAnnouncement() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .collection('announcements')
            .add({
          'message': _messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement added successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding announcement: $e'), backgroundColor: kErrorColor),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Announcement'),
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
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Message',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.announcement, color: kTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 5,
                    validator: (value) => value!.isEmpty ? 'Please enter an announcement message' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addAnnouncement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: kTextColor)
                        : const Text(
                            'Add Announcement',
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