import 'package:flutter/material.dart';

class PaySlipScreen extends StatefulWidget {
  @override
  _PaySlipScreenState createState() => _PaySlipScreenState();
}

class _PaySlipScreenState extends State<PaySlipScreen> {
  String? _selectedMonth = 'Jan2025';

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
          'Pay Slip',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false, // Remove back arrow
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Month'),
              value: _selectedMonth,
              items: ['Jan2025', 'Feb2025', 'Mar2025', 'Apr2025', 'May2025'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMonth = value;
                });
              },
            ),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Payslip for the month of $_selectedMonth',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDetailRow('Name', 'MISS Madhuri Pravin Bhaisare'),
                    _buildDetailRow('Designation', 'Assistant Professor'),
                    _buildDetailRow('Staff', 'Yes'),
                    _buildDetailRow('Employee Code', 'EMP12345'),
                    _buildDetailRow('Department', 'Computer Science'),
                    _buildDetailRow('PAN No', 'ABCDE1234F'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salary Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDetailRow('Total Gross', '₹50,000'),
                    _buildDetailRow('Total Deduction', '₹5,000'),
                    _buildDetailRow('Net Pay', '₹45,000'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank & Salary Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDetailRow('PF No', 'PF123456'),
                    _buildDetailRow('Bank', 'SBI'),
                    _buildDetailRow('Account No', '1234567890'),
                    _buildDetailRow('Scale', 'Level 10'),
                    _buildDetailRow('Basic', '₹30,000'),
                    _buildDetailRow('GP/DP', '₹10,000'),
                    _buildDetailRow('Pay', '₹40,000'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income Heads', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    _buildDetailRow('DA', '₹5,000'),
                    _buildDetailRow('DA NT', '₹2,000'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }
}