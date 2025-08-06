import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14B8A6), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          _buildNotificationItem('New message from Admin', '05:20 PM, Jul 31, 2025'),
          _buildNotificationItem('Schedule updated', '04:50 PM, Jul 31, 2025'),
          _buildNotificationItem('Leave approved', '03:15 PM, Jul 31, 2025'),
          _buildNotificationItem('Payroll notice available', '02:00 PM, Jul 31, 2025'),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String time) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(Icons.notifications, color: Color(0xFF1D70B9)),
        title: Text(title),
        subtitle: Text(time),
        trailing: Icon(Icons.circle, size: 10, color: Colors.green),
      ),
    );
  }
}