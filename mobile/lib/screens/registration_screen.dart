import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:dio/dio.dart';
import '../config.dart';
import '../widgets/glass_container.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _countryCode = '+91'; // Default to India
  String _step = 'form'; // 'form' or 'otp'
  bool _isLoading = false;
  String _blockMessage = '';

  final List<Map<String, dynamic>> _countries = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳', 'length': 10},
    {'code': '+1', 'name': 'USA', 'flag': '🇺🇸', 'length': 10},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧', 'length': 10},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺', 'length': 9},
  ];

  int _getSelectedCountryLength() {
    final country = _countries.firstWhere((c) => c['code'] == _countryCode);
    return country['length'] as int;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _blockMessage = '';
    });

    final finalPhone = '$_countryCode${_phoneController.text.trim()}';

    try {
      final dio = Dio();
      final response = await dio.post(
        '${AppConfig.supabaseUrl}/functions/v1/mail-service/send-otp',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'phone': finalPhone,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _step = 'otp';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email!'),
            backgroundColor: Colors.indigoAccent,
          ),
        );
      } else {
        throw Exception('Failed to send verification code.');
      }
    } on DioException catch (e) {
      String errMsg = 'Failed to request code.';
      if (e.response?.statusCode == 429) {
        _blockMessage = e.response?.data['error'] ?? 'Too many requests. Please try again later.';
      } else {
        errMsg = e.response?.data['error'] ?? 'Connection error. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final finalPhone = '$_countryCode${_phoneController.text.trim()}';

    try {
      final dio = Dio();
      final response = await dio.post(
        '${AppConfig.supabaseUrl}/functions/v1/mail-service/verify-otp',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'phone': finalPhone,
          'otp': _otpController.text.trim(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Request Submitted', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Your email has been verified and registration request submitted. Login will become active once approved by an administrator.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop dialog
                  Navigator.pop(context); // Pop screen back to login
                },
                child: const Text('OK', style: TextStyle(color: Colors.indigoAccent)),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Verification failed.');
      }
    } on DioException catch (e) {
      final errMsg = e.response?.data['error'] ?? 'OTP verification failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Access',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: GlassContainer(
            child: Form(
              key: _formKey,
              child: _step == 'form' ? _buildFormStep() : _buildOtpStep(),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildFormStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Console Access',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter details to request backend access.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // Warning
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade500.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade500.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.amber.shade400, size: 16),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your Google login email must match the registration email requested here.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Name input
        const Text('FULL NAME', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _buildInputDecoration(LucideIcons.user, 'John Doe'),
          validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 18),

        // Phone input
        const Text('PHONE NUMBER', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFF080D1A).withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: const Color(0xFF0F172A),
                  value: _countryCode,
                  items: _countries.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Text('${c['flag']} ${c['code']}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _countryCode = val;
                        final maxLen = _getSelectedCountryLength();
                        if (_phoneController.text.length > maxLen) {
                          _phoneController.text = _phoneController.text.substring(0, maxLen);
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(LucideIcons.phone, '9876543210'),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_getSelectedCountryLength()),
                ],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Phone is required';
                  final numeric = val.replaceAll(RegExp(r'\D'), '');
                  final country = _countries.firstWhere((c) => c['code'] == _countryCode);
                  final requiredLength = country['length'] as int;
                  if (numeric.length != requiredLength) {
                    return 'Must be $requiredLength digits';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Email input
        const Text('EMAIL ADDRESS', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _buildInputDecoration(LucideIcons.mail, 'your-google-email@gmail.com'),
          validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 24),

        if (_blockMessage.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Text(
              _blockMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],

        // Submit Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            disabledBackgroundColor: Colors.indigo.shade600.withOpacity(0.5),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Request Console Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Verification code sent to ${_emailController.text}',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        const SizedBox(height: 20),

        // OTP Input
        const Text('ENTER 6-DIGIT CODE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF080D1A).withOpacity(0.8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
          ),
        ),
        const SizedBox(height: 24),

        // Verify Button
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verify Email & Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 16),

        // Back button / Resend Option
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 'form'),
              child: const Text('Change Details', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ),
            TextButton(
              onPressed: _isLoading ? null : _handleSendOtp,
              child: const Text('Resend Code', style: TextStyle(color: Colors.indigoAccent, fontSize: 12)),
            ),
          ],
        )
      ],
    );
  }

  InputDecoration _buildInputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF080D1A).withOpacity(0.8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
    );
  }
}
