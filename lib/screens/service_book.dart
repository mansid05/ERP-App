import 'package:flutter/material.dart';

class ServiceBookScreen extends StatelessWidget {
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
          'Service Book',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuItem('Personal Memoranda'),
            _buildMenuItem('Admin Responsibilities'),
            _buildMenuItem('Departmental Examination'),
            _buildMenuItem('Family Details'),
            _buildMenuItem('Invited Talk'),
            _buildMenuItem('Pay Leave'),
            _buildMenuItem('Loan And Advance'),
            _buildMenuItem('LTC'),
            _buildMenuItem('Matter Data'),
            _buildMenuItem('Nomination'),
            _buildMenuItem('Previous Experience'),
            _buildMenuItem('Publication Details'),
            _buildMenuItem('Qualification'),
            _buildMenuItem('Pay Revision/Promotion'),
            _buildMenuItem('Training Details'),
            _buildMenuItem('Transaction Type Details'),
            _buildMenuItem('Financial Support/Financial Assistance Details'),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(Icons.book, color: Color(0xFF1D70B9)),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}