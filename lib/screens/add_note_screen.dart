import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class AddNoteScreen extends StatefulWidget {
  final String courseId;
  final String? noteId;
  final Map<String, dynamic>? noteData;

  const AddNoteScreen({
    super.key,
    required this.courseId,
    this.noteId,
    this.noteData,
  });

  @override
  _AddNoteScreenState createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.noteData != null) {
      _titleController.text = widget.noteData!['title'] ?? '';
      _contentController.text = widget.noteData!['content'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Save or update a note in Firestore
  Future<void> _handleSaveNote() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final noteData = {
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        final collection = FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('notes');

        if (widget.noteId != null) {
          await collection.doc(widget.noteId).update(noteData);
        } else {
          await collection.add(noteData);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note saved successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving note: $e'), backgroundColor: kErrorColor),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Reusable TextField widget
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextField(
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
      onChanged: validator != null ? (value) => setState(() {}) : null,
    );
  }

  // Reusable ElevatedButton widget
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
        title: Text(widget.noteId == null ? 'Add Note' : 'Edit Note'),
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
                    const Icon(Icons.note_add, size: 100, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      widget.noteId == null ? 'Add Note' : 'Edit Note',
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
                      'Create or update a note for your course',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Note Title',
                      icon: Icons.title,
                      validator: (value) => value!.isEmpty ? 'Please enter the note title' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contentController,
                      label: 'Note Content',
                      icon: Icons.edit,
                      maxLines: 6,
                      validator: (value) => value!.isEmpty ? 'Please enter the note content' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      onPressed: _handleSaveNote,
                      label: widget.noteId == null ? 'Save Note' : 'Update Note',
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