import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/owner_signup.dart';
import 'owner_signup_step3_screen.dart';
import 'helper.dart';

class BusinessOwnerSignUpStep2Screen extends StatefulWidget {
  const BusinessOwnerSignUpStep2Screen({super.key});

  @override
  State<BusinessOwnerSignUpStep2Screen> createState() =>
      _BusinessOwnerSignUpStep2ScreenState();
}

class _BusinessOwnerSignUpStep2ScreenState
    extends State<BusinessOwnerSignUpStep2Screen> {
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _publicEmailController = TextEditingController();

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _publicEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 2: Business Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 2 / 3,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(primaryPink),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Set Up Your Business Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This information will be visible to your clients on your booking page.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 24),

                // Business Name
                const _OwnerFieldLabel('Business Name'),
                const SizedBox(height: 8),
                buildOwnerTextField(
                  controller: _businessNameController,
                  hintText: 'Enter your business name',
                ),

                const SizedBox(height: 16),

                // Business Type
                const _OwnerFieldLabel('Business Type'),
                const SizedBox(height: 8),
                TextField(
                  controller: _businessTypeController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Select business type',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: primaryPink,
                        width: 1.4,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(Icons.keyboard_arrow_down),
                  ),
                  onTap: () {
                    // TODO: Dropdown aç (bottom sheet vs.)
                  },
                ),

                const SizedBox(height: 16),

                // Business Address
                const _OwnerFieldLabel('Business Address'),
                const SizedBox(height: 8),
                buildOwnerTextField(
                  controller: _streetController,
                  hintText: 'e.g. 123 Main St',
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _OwnerFieldLabel('City'),
                          const SizedBox(height: 8),
                          buildOwnerTextField(
                            controller: _cityController,
                            hintText: 'Your city',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _OwnerFieldLabel('State'),
                          const SizedBox(height: 8),
                          buildOwnerTextField(
                            controller: _stateController,
                            hintText: 'Your state',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                const _OwnerFieldLabel('Postal Code'),
                const SizedBox(height: 8),
                buildOwnerTextField(
                  controller: _postalCodeController,
                  hintText: 'Your postal code',
                ),

                const SizedBox(height: 16),

                // Contact Information
                const _OwnerFieldLabel('Contact Information'),
                const SizedBox(height: 8),

                const _OwnerFieldLabel('Phone Number', small: true),
                const SizedBox(height: 8),
                buildOwnerTextField(
                  controller: _phoneController,
                  hintText: '(123) 456-7890',
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 12),

                const _OwnerFieldLabel('Public Email', small: true),
                const SizedBox(height: 8),
                buildOwnerTextField(
                  controller: _publicEmailController,
                  hintText: 'contact@business.com',
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 16),

                // Business logo
                const _OwnerFieldLabel('Business Logo (Optional)'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                    color: Colors.white,
                    // Noktalı sınır efekti için:
                    // henüz gerçek dashed border yok, bu görsel açıdan benzeri
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.cloud_upload_outlined),
                      SizedBox(height: 8),
                      Text(
                        'Click to upload or drag and drop',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryPink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SVG, PNG, JPG or GIF (max. 800x400px)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Back & Continue
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final model = OwnerSignupModel.instance;
                            model.businessName = _businessNameController.text.trim();
                            model.businessType = _businessTypeController.text.trim();
                            model.street = _streetController.text.trim();
                            model.city = _cityController.text.trim();
                            model.state = _stateController.text.trim();
                            model.postalCode = _postalCodeController.text.trim();
                            model.phone = _phoneController.text.trim();
                            model.publicEmail = _publicEmailController.text.trim();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const BusinessOwnerSignUpStep3Screen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerFieldLabel extends StatelessWidget {
  final String text;
  final bool small;

  const _OwnerFieldLabel(this.text, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: small ? 12 : 13,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }
}
