import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Constants for consistent styling
const kPrimaryColor = Color(0xFF4A90E2);
const kSecondaryColor = Color(0xFF50E3C2);
const kTextColor = Color(0xFF0D47A1);
const kErrorColor = Color(0xFFF44336);
const kSuccessColor = Color(0xFF4CAF50);

class AddAssignmentScreen extends StatefulWidget {
  final String courseId;
  final String? assignmentId;
  final Map<String, dynamic>? assignmentData;

  const AddAssignmentScreen({
    super.key,
    required this.courseId,
    this.assignmentId,
    this.assignmentData,
  });

  @override
  _AddAssignmentScreenState createState() => _AddAssignmentScreenState();
}

class _AddAssignmentScreenState extends State<AddAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignmentData != null) {
      _titleController.text = widget.assignmentData!['title'] ?? '';
      _descriptionController.text = widget.assignmentData!['description'] ?? '';
      _contentController.text = widget.assignmentData!['content'] ?? '';
      _dueDate = (widget.assignmentData!['dueDate'] as Timestamp?)?.toDate();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleAddAssignment() async {
    if (_formKey.currentState!.validate()) {
      if (_dueDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a due date'), backgroundColor: kErrorColor),
        );
        return;
      }
      if (_dueDate!.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Due date must be in the future'), backgroundColor: kErrorColor),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final assignmentData = {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'content': _contentController.text.trim(),
          'dueDate': Timestamp.fromDate(_dueDate!),
          'createdAt': FieldValue.serverTimestamp(),
        };

        final collection = FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .collection('assignments');

        if (widget.assignmentId != null) {
          await collection.doc(widget.assignmentId).update(assignmentData);
        } else {
          await collection.add(assignmentData);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment saved successfully!'), backgroundColor: kSuccessColor),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving assignment: $e'), backgroundColor: kErrorColor),
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
        title: Text(widget.assignmentId == null ? 'Add Assignment' : 'Edit Assignment'),
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
                    const Icon(Icons.assignment_add, size: 100, color: Colors.white),
                    const SizedBox(height: 24),
                    Text(
                      widget.assignmentId == null ? 'Add Assignment' : 'Edit Assignment',
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
                      'Create or update an assignment for your course',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Assignment Title',
                      icon: Icons.assignment,
                      validator: (value) => value!.isEmpty ? 'Please enter the assignment title' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Assignment Description',
                      icon: Icons.description,
                      maxLines: 4,
                      validator: (value) => value!.isEmpty ? 'Please enter the assignment description' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contentController,
                      label: 'Assignment Content',
                      icon: Icons.edit,
                      maxLines: 6,
                      validator: (value) => value!.isEmpty ? 'Please enter the assignment content' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (selectedDate != null) {
                          setState(() => _dueDate = selectedDate);
                        }
                      },
                      label: _dueDate == null ? 'Select Due Date' : 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}',
                    ),
                    const SizedBox(height: 24),
                    _buildButton(
                      onPressed: _handleAddAssignment,
                      label: widget.assignmentId == null ? 'Save Assignment' : 'Update Assignment',
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