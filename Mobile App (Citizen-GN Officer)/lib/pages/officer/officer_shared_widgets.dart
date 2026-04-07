import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class OfficerSummaryCard extends StatelessWidget {
  const OfficerSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (color ?? AppColors.primary).withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color ?? AppColors.primary, size: 22),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class OfficerAlertTile extends StatelessWidget {
  const OfficerAlertTile({
    super.key,
    required this.text,
    required this.time,
    this.high = false,
  });

  final String text;
  final String time;
  final bool high;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (high ? AppColors.warning : AppColors.primary).withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            high ? Icons.priority_high_rounded : Icons.notifications_none_rounded,
            color: high ? AppColors.warning : AppColors.primary,
          ),
        ),
        title: Text(
          text,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            time,
            style: GoogleFonts.inter(color: AppColors.mutedForeground, fontSize: 12),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.border),
      ),
    );
  }
}

class OfficerFilterChip extends StatelessWidget {
  const OfficerFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
    );
  }
}

class OfficerInfoRow extends StatelessWidget {
  const OfficerInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: AppColors.mutedForeground),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfficerDocChip extends StatelessWidget {
  const OfficerDocChip({super.key, required this.name, this.isImage = false});

  final String name;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded),
          const SizedBox(height: 4),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
