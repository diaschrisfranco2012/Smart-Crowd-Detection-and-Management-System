// import 'package:flutter/material.dart';
//
// class StatCard extends StatelessWidget {
//   final String title;
//   final String value;
//   final IconData icon;
//   final Color highlightColor;
//
//   const StatCard({
//     super.key,
//     required this.title,
//     required this.value,
//     required this.icon,
//     required this.highlightColor,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.grey[900],
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: highlightColor.withOpacity(0.5),
//           width: 2,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment:
//             CrossAxisAlignment.start,
//         children: [
//           Icon(
//             icon,
//             color: Colors.white,
//             size: 30,
//           ),
//           const SizedBox(height: 20),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 48,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           const SizedBox(height: 5),
//           Text(
//             title,
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
