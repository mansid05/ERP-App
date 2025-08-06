import 'package:erp_app/screens/service_book.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2553A1), Color(0xFF2B7169)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        toolbarHeight: 120,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(),
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            Text(
              'MISS Madhuri Pravin Bhaisare',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            Text(
              'ASSISTANT PROFESSOR',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0), // Curved borders
              child: Image.asset(
                'assets/logo.jpg',
                height: 100,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'NAGARJUNA INSTITUTE OF ENGINEERING, TECHNOLOGY & MANAGEMENT\n2024-2025',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Search Student',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My To Do Details'),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {},
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildIconButton(Icons.check_circle, 'Mark\nAttendance', onTap: () {  }),
                _buildIconButton(Icons.history, 'Attendance\nLog', onTap: () {  }),
                _buildIconButton(Icons.dashboard, 'Dashboard', onTap: () {  }),
                _buildIconButton(Icons.calendar_today, 'Class\nSchedule', onTap: () {  }),
                _buildIconButton(Icons.notifications, 'Send\nNotification', onTap: () {  }),
                _buildIconButton(Icons.receipt, 'Pay Slip', onTap: () {  }),
                _buildIconButton(Icons.edit, 'Apply\nLeave', onTap: () {  }),
                _buildIconButton(Icons.work, 'Comp\nOff', onTap: () {  }),
                _buildIconButton(Icons.check, 'Approve\nLeave', onTap: () {  }),
                _buildIconButton(Icons.edit_attributes, 'Approve\nOD Leave', onTap: () {  }),
                _buildIconButton(Icons.book, 'OD\nLeave', onTap: () {  }),
                _buildIconButton(Icons.bookmark, 'Service\nBook', onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ServiceBookScreen()),
                  );
                }),
                _buildIconButton(Icons.swap_horiz, 'In\nOut', onTap: () {  }),
                _buildIconButton(Icons.calendar_today, 'Calendar', onTap: () {  }),
                _buildIconButton(Icons.notification_important, 'Payroll\nNotice', onTap: () {  }),
                _buildIconButton(Icons.check_circle, 'Approve\nComp Off', onTap: () {  }),
                _buildIconButton(Icons.handshake, 'Approve\nCharge Handover', onTap: () {  }),
                _buildIconButton(Icons.swap_horiz, 'OD Leave\nApprove', onTap: () {  }),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text('Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pending Approval'),
                        Text('0', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text('OD Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Pending Approval'),
                        Text('0', style: TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(icon, color: Color(0xFF1D70B9)),
              onPressed: onTap ?? () {},
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}