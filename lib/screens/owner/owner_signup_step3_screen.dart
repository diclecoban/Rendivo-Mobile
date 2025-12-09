import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BusinessOwnerSignUpStep3Screen extends StatelessWidget {
  const BusinessOwnerSignUpStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Üst: Rendivo + profil ikonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Rendivo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryPink,
                      child: Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Step 3 of 3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 1,
                    minHeight: 6,
                    backgroundColor: Colors.grey,
                    valueColor: const AlwaysStoppedAnimation(primaryPink),
                  ),
                ),

                const SizedBox(height: 32),

                // Check icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 56,
                    color: primaryPink,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "You're all set!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Welcome to Rendivo, The Chic Salon!\nYou're ready to start managing your appointments.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Summary card
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Business Details Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Here's the information we have on file for your business.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Business Name: The Chic Salon',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Category: Beauty & Wellness',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Contact: contact@chicsalon.com',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "What's next?",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Add first service card
                _NextActionCard(
                  icon: Icons.brush,
                  title: 'Add Your First Service',
                ),

                const SizedBox(height: 12),

                // Invite team card
                _NextActionCard(
                  icon: Icons.group_outlined,
                  title: 'Invite Your Team',
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Business onboarding will be re-enabled after integrating the new API.',
                          ),
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
                      'Go to Your Dashboard',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Step2'ye geri
                  },
                  child: const Text(
                    'Go back and edit details',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _NextActionCard({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryPink),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          )
        ],
      ),
    );
  }
}
