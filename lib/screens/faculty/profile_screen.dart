import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Profile'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {},
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile_image.jpg'), // Replace with actual image path
                  child: Icon(Icons.person, size: 40, color: Colors.grey), // Placeholder if no image
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'MISS Madhuri Pravin Bhaisare - ASSISTANT PROFESSOR',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildMenuItem(Icons.person, 'Personal Detail', () {}),
            _buildMenuItem(Icons.edit, 'Update Profile Photo & Sign', () {}),
            _buildMenuItem(Icons.shield, 'Privacy Policy', () {}),
            _buildMenuItem(Icons.help, 'Support', () {}),
            _buildMenuItem(Icons.lock, 'Change Password', () {}),
            _buildMenuItem(Icons.share, 'Share App', () {}),
            _buildMenuItem(Icons.star, 'Rate App', () {}),
            _buildMenuItem(Icons.logout, 'Log out', () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
