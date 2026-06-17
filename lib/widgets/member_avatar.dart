import 'package:flutter/material.dart';
import '../models/member_model.dart';
import '../theme/app_theme.dart';

class MemberAvatar extends StatelessWidget {
  final MemberModel member;
  final double radius;
  final double? fontSize;

  const MemberAvatar({
    super.key,
    required this.member,
    this.radius = 20,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = (member.prenom.isNotEmpty ? member.prenom[0] : '') +
                     (member.nom.isNotEmpty ? member.nom[0] : '');
    
    final Color color;
    final Color bgColor;

    if (member.genre == 'F') {
      color = Colors.pink;
      bgColor = Colors.pink[100]!;
    } else {
      color = isDark ? AppTheme.gold : AppTheme.darkBlue;
      bgColor = isDark ? AppTheme.darkBlue : Colors.blue[100]!;
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
      child: member.photoUrl.isEmpty
          ? Text(
              initials.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: fontSize ?? radius * 0.8,
              ),
            )
          : null,
    );
  }
}
