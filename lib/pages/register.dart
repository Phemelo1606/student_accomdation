import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:student_accomdation/features/auth/auth_service.dart';
import 'package:student_accomdation/pages/landlordRegistration.dart';
import 'package:student_accomdation/pages/login.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _facultyController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _yearOfStudyController = TextEditingController();
  final TextEditingController _digitalLiteracyController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      // Use the enhanced AuthService to create user with student role
      final userCredential = await authService.value.createUser(
        email: email,
        password: password,
        role: 'student',
        additionalData: {
          'name': _nameController.text.trim(),
          'studentID': _studentIdController.text.trim(),
          'age': int.tryParse(_ageController.text.trim()) ?? 0,
          'faculty': _facultyController.text.trim(),
          'yearOfStudy': _yearOfStudyController.text.trim(),
          'digitalLiteracy': _digitalLiteracyController.text.trim(),
          'userType': 'student',
        },
      );

      final user = userCredential.user;
      if (user == null) throw Exception("User creation failed");

      // Update user display name
      await user.updateDisplayName(_nameController.text.trim());

      // Save student-specific info in Students collection
      await authService.value.updateUserData({
        'StudentID': _studentIdController.text.trim(),
        'Name': _nameController.text.trim(),
        'Age': int.tryParse(_ageController.text.trim()) ?? 0,
        'StudentEmail': email,
        'Faculty': _facultyController.text.trim(),
        'YearOfStudy': _yearOfStudyController.text.trim(),
        'DigitalLiteracy': _digitalLiteracyController.text.trim(),
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Student registration successful!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Registration failed";
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = "This email is already registered";
          break;
        case 'invalid-email':
          errorMessage = "Please enter a valid email address";
          break;
        case 'operation-not-allowed':
          errorMessage = "Email/password accounts are not enabled";
          break;
        case 'weak-password':
          errorMessage = "Password is too weak";
          break;
        default:
          errorMessage = e.message ?? "Registration failed";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("An error occurred: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
          child: Column(
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 22,
                    child: Icon(Icons.school, color: Colors.indigo[900]),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "SMART STUDENT ACCOMMODATION\nFOR CUT STUDENTS",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      buildTextField("Student ID", _studentIdController,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your student ID";
                        }
                        if (value.length < 3) {
                          return "Please enter a valid student ID";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField("Full Name", _nameController,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your full name";
                        }
                        if (value.length < 2) {
                          return "Name must be at least 2 characters";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField("Age", _ageController,
                          inputType: TextInputType.number, validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your age";
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 16 || age > 100) {
                          return "Please enter a valid age (16-100)";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField("CUT Email", _emailController,
                          inputType: TextInputType.emailAddress,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your email";
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return "Please enter a valid email address";
                        }
                        if (!value.toLowerCase().contains('cut.ac.za')) {
                          return "Please use your CUT email address";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField("Faculty", _facultyController,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your faculty";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField("Year of Study", _yearOfStudyController,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your year of study";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildTextField(
                          "Digital Literacy Level", _digitalLiteracyController,
                          validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your digital literacy level";
                        }
                        return null;
                      }),
                      const SizedBox(height: 15),
                      buildPasswordField(
                          "Password", _passwordController, false),
                      const SizedBox(height: 15),
                      buildPasswordField(
                          "Confirm Password", _confirmPasswordController, true),
                      const SizedBox(height: 25),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[900],
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading ? null : registerStudent,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Register as Student",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Landlord link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Are you a Landlord? "),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            LandlordRegisterScreen(),
                                      ),
                                    );
                                  },
                            child: Text(
                              "Register As Landlord",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isLoading
                                    ? Colors.grey
                                    : Colors.indigo[900],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Sign in link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LoginScreen(),
                                      ),
                                    );
                                  },
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isLoading
                                    ? Colors.grey
                                    : Colors.indigo[900],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      validator: validator ??
          (value) => value == null || value.isEmpty ? "Enter $label" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.indigo),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget buildPasswordField(
      String label, TextEditingController controller, bool confirmField) {
    return TextFormField(
      controller: controller,
      obscureText: confirmField ? _obscureConfirmPassword : _obscurePassword,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Please enter $label";
        }
        if (!confirmField && value.length < 6) {
          return "Password must be at least 6 characters";
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.indigo),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            (confirmField ? _obscureConfirmPassword : _obscurePassword)
                ? Icons.visibility_off
                : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              if (confirmField) {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              } else {
                _obscurePassword = !_obscurePassword;
              }
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _facultyController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _yearOfStudyController.dispose();
    _digitalLiteracyController.dispose();
    super.dispose();
  }
}
