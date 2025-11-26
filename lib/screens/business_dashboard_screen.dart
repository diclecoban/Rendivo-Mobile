import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ÜST: Selamlama + ikon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, Radiant Salon!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Here's what's happening with your business.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryPink,
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // KPI kartları (ilk satır 2 tane)
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      title: 'Total Appointments Today',
                      mainValue: '12',
                      trendText: '+2% from yesterday',
                      trendColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      title: 'New Clients This Week',
                      mainValue: '8',
                      trendText: '+5% from last week',
                      trendColor: Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // KPI kartı (Revenue)
              _KpiCard(
                title: 'Projected Revenue',
                mainValue: r'$2,450',
                trendText: '+15% from yesterday',
                trendColor: Colors.green,
              ),

              const SizedBox(height: 16),

              // Upcoming Appointments
              _SectionTitle('Upcoming Appointments'),
              const SizedBox(height: 8),
              _CardContainer(
                child: Column(
                  children: const [
                    _AppointmentRow(
                      avatarLabel: 'C',
                      service: 'Haircut & Style – Chloe',
                      client: 'Isabella Rossi',
                      time: '9:00 AM',
                    ),
                    Divider(height: 16),
                    _AppointmentRow(
                      avatarLabel: 'A',
                      service: 'Manicure – Alex',
                      client: 'Sophia Chen',
                      time: '10:30 AM',
                    ),
                    Divider(height: 16),
                    _AppointmentRow(
                      avatarLabel: 'J',
                      service: 'Balayage – Jordan',
                      client: 'Olivia Kim',
                      time: '11:00 AM',
                    ),
                    Divider(height: 16),
                    _AppointmentRow(
                      avatarLabel: 'S',
                      service: 'Facial – Sam',
                      client: 'Ava Garcia',
                      time: '1:00 PM',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Staff Availability
              _SectionTitle('Staff Availability'),
              const SizedBox(height: 8),
              Stack(
                children: [
                  _CardContainer(
                    child: Column(
                      children: const [
                        _StaffAvailabilityRow(
                          avatarLabel: 'C',
                          name: 'Chloe',
                          statusText: 'BUSY',
                          statusColor: Colors.redAccent,
                        ),
                        SizedBox(height: 12),
                        _StaffAvailabilityRow(
                          avatarLabel: 'A',
                          name: 'Alex',
                          statusText: 'AVAILABLE',
                          statusColor: Colors.green,
                        ),
                        SizedBox(height: 12),
                        _StaffAvailabilityRow(
                          avatarLabel: 'J',
                          name: 'Jordan',
                          statusText: 'ON BREAK',
                          statusColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        // TODO: Yeni staff ekle
                      },
                      backgroundColor: primaryPink,
                      elevation: 1,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Popular Services
              _SectionTitle('Popular Services'),
              const SizedBox(height: 8),
              _CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ServiceProgressRow(
                      service: 'Haircut & Style',
                      value: 0.45,
                      percentageLabel: '45%',
                    ),
                    SizedBox(height: 12),
                    _ServiceProgressRow(
                      service: 'Balayage',
                      value: 0.25,
                      percentageLabel: '25%',
                    ),
                    SizedBox(height: 12),
                    _ServiceProgressRow(
                      service: 'Manicure',
                      value: 0.20,
                      percentageLabel: '20%',
                    ),
                    SizedBox(height: 12),
                    _ServiceProgressRow(
                      service: 'Facial',
                      value: 0.10,
                      percentageLabel: '10%',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────── Helper Widgetlar ─────────────────

class _KpiCard extends StatelessWidget {
  final String title;
  final String mainValue;
  final String trendText;
  final Color trendColor;

  const _KpiCard({
    required this.title,
    required this.mainValue,
    required this.trendText,
    required this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trendText,
            style: TextStyle(
              fontSize: 11,
              color: trendColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final String avatarLabel;
  final String service;
  final String client;
  final String time;

  const _AppointmentRow({
    required this.avatarLabel,
    required this.service,
    required this.client,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: primaryPink.withOpacity(0.2),
          child: Text(
            avatarLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryPink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                client,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _StaffAvailabilityRow extends StatelessWidget {
  final String avatarLabel;
  final String name;
  final String statusText;
  final Color statusColor;

  const _StaffAvailabilityRow({
    required this.avatarLabel,
    required this.name,
    required this.statusText,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: primaryPink.withOpacity(0.15),
          child: Text(
            avatarLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryPink,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceProgressRow extends StatelessWidget {
  final String service;
  final double value;
  final String percentageLabel;

  const _ServiceProgressRow({
    required this.service,
    required this.value,
    required this.percentageLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                service,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Text(
              percentageLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(primaryPink),
          ),
        ),
      ],
    );
  }
}
