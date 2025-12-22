import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;

  const HomeScreen({
    Key? key,
    this.user,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          user?['name'] ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Quick Actions
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.add_circle,
                                title: 'Report Lost',
                                subtitle: 'Lost something?',
                                color: const Color(0xFFef4444),
                                onTap: () {
                                  // Navigate to report lost
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.search,
                                title: 'Found Item',
                                subtitle: 'Found something?',
                                color: const Color(0xFF10b981),
                                onTap: () {
                                  // Navigate to report found
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Recent Activity
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.inbox, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No recent activity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Your posted items and matches will appear here',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
