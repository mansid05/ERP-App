import 'package:flutter/material.dart';

class ODLeaveScreen extends StatelessWidget {
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
          'Od Leave',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false, // Remove back arrow
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildODCard('OD APPLICATION', {
            'Purpose': 'Training',
            'Event': 'Workshop',
            'Reason': 'Skill Development',
            'From Date / To Date': '01/08/2025 - 02/08/2025',
            'Leave Days / Joining Date': '2 Days / 03/08/2025',
            'Status': 'Approved',
          }),
          _buildODCard('OD SLIP', {
            'Purpose': 'Seminar',
            'Event': 'Conference',
            'Reason': 'Presentation',
            'From Date / To Date': '05/08/2025 - 06/08/2025',
            'Leave Days / Joining Date': '2 Days / 07/08/2025',
            'Status': 'Pending',
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
        backgroundColor: Color(0xFF1D70B9),
      ),
    );
  }

  Widget _buildODCard(String title, Map<String, String> fields) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Table(
              columnWidths: {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.5),
              },
              children: fields.entries.map((entry) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(entry.key),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(entry.value),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}