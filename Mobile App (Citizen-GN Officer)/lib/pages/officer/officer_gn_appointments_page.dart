import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../localization/app_localizations.dart';
import '../../models/gn_appointment.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_page_app_bar.dart';
import 'officer_shared_widgets.dart';

class OfficerGnAppointmentsPage extends StatefulWidget {
  const OfficerGnAppointmentsPage({super.key});

  @override
  State<OfficerGnAppointmentsPage> createState() =>
      _OfficerGnAppointmentsPageState();
}

class _OfficerGnAppointmentsPageState extends State<OfficerGnAppointmentsPage> {
  final TextEditingController _search = TextEditingController();
  late Future<UserModel?> _officerFuture;
  String _filter = 'all';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _officerFuture = firestoreService.getUser(firestoreService.currentUserId);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
    UserModel officer,
    GnAppointment appointment,
    String status, {
    String? officerNotes,
    DateTime? scheduledDate,
    List<String>? expectedCurrentStatuses,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await firestoreService.updateGnAppointmentStatus(
        appointment.id,
        status,
        officerNotes: officerNotes,
        scheduledDate: scheduledDate,
        expectedCurrentStatuses: expectedCurrentStatuses,
        actingOfficerId: officer.id,
        actingOfficerName: officer.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('officerAppointmentUpdated'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('officerAppointmentUpdateFailed')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleApprove(
    UserModel officer,
    GnAppointment appointment,
  ) async {
    final notes = await _collectNotes(
      title: context.tr('officerApproveAppointment'),
      hint: context.tr('officerApproveHint'),
      confirmLabel: context.tr('actionApprove'),
    );
    if (notes == null) return;
    await _updateStatus(
      officer,
      appointment,
      'Approved',
      officerNotes: notes,
      expectedCurrentStatuses: const ['Requested'],
    );
  }

  Future<void> _handleDecline(
    UserModel officer,
    GnAppointment appointment,
  ) async {
    final notes = await _collectNotes(
      title: context.tr('officerDeclineAppointment'),
      hint: context.tr('officerDeclineHint'),
      confirmLabel: context.tr('actionDecline'),
      destructive: true,
    );
    if (notes == null) return;
    await _updateStatus(
      officer,
      appointment,
      'Declined',
      officerNotes: notes,
      expectedCurrentStatuses: const ['Requested'],
    );
  }

  Future<void> _handleComplete(
    UserModel officer,
    GnAppointment appointment,
  ) async {
    final notes = await _collectNotes(
      title: context.tr('officerMarkCompleted'),
      hint: context.tr('officerCompleteHint'),
      confirmLabel: context.tr('actionMarkCompleted'),
    );
    if (notes == null) return;
    await _updateStatus(
      officer,
      appointment,
      'Completed',
      officerNotes: notes,
      expectedCurrentStatuses: const ['Approved', 'Rescheduled'],
    );
  }

  Future<void> _handleReschedule(
    UserModel officer,
    GnAppointment appointment,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: appointment.scheduledDate ?? appointment.preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: context.tr('officerSelectNewDate'),
    );
    if (!mounted || picked == null) return;

    final notes = await _collectNotes(
      title: context.tr('officerRescheduleAppointment'),
      hint: context.tr('officerRescheduleHint'),
      confirmLabel: context.tr('save'),
      extraLabel:
          '${context.tr('officerNewDatePrefix')}: ${DateFormat.yMMMMEEEEd().format(picked)}',
    );
    if (notes == null) return;

    await _updateStatus(
      officer,
      appointment,
      'Rescheduled',
      officerNotes: notes,
      scheduledDate: picked,
      expectedCurrentStatuses: const ['Requested'],
    );
  }

  Future<String?> _collectNotes({
    required String title,
    required String hint,
    required String confirmLabel,
    String? extraLabel,
    bool destructive = false,
  }) async {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                if (extraLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    extraLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(context.tr('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, controller.text.trim());
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: destructive
                              ? AppColors.destructive
                              : AppColors.primary,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusFilterLabel(String filter) {
    switch (filter) {
      case 'requested':
        return context.tr('statusRequested');
      case 'attention':
        return 'Needs attention';
      case 'today':
        return 'Today';
      case 'approved':
        return context.tr('statusApproved');
      case 'rescheduled':
        return context.tr('statusRescheduled');
      case 'declined':
        return context.tr('statusDeclined');
      case 'completed':
        return context.tr('completed');
      default:
        return context.tr('all');
    }
  }

  String _statusDisplayLabel(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return context.tr('statusRequested');
      case 'approved':
        return context.tr('statusApproved');
      case 'rescheduled':
        return context.tr('statusRescheduled');
      case 'declined':
        return context.tr('statusDeclined');
      case 'completed':
        return context.tr('completed');
      case 'cancelled':
        return context.tr('cancelAppointment');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: context.tr('officerGnAppointmentsTitle'),
        subtitle: context.tr('officerGnAppointmentsSubtitle'),
      ),
      body: FutureBuilder<UserModel?>(
        future: _officerFuture,
        builder: (context, officerSnapshot) {
          final officer = officerSnapshot.data;

          if (officerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (officer == null) {
            return Center(child: Text(context.tr('officerProfileLoadError')));
          }

          return StreamBuilder<List<GnAppointment>>(
            stream: firestoreService.getOfficerScopedGnAppointments(officer),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(context.tr('officerAppointmentsLoadError')),
                );
              }

              final items = List<GnAppointment>.from(snapshot.data ?? const [])
                ..sort((a, b) {
                  final urgentCompare = (b.isUrgent ? 1 : 0).compareTo(
                    a.isUrgent ? 1 : 0,
                  );
                  if (urgentCompare != 0) {
                    return urgentCompare;
                  }

                  final aDate = a.scheduledDate ?? a.preferredDate;
                  final bDate = b.scheduledDate ?? b.preferredDate;
                  return aDate.compareTo(bDate);
                });

              final requested = items
                  .where((item) => item.status == 'Requested')
                  .length;
              final needsAttention = items
                  .where(
                    (item) =>
                        item.status == 'Requested' ||
                        item.status == 'Rescheduled',
                  )
                  .length;

              final assignedGnDivision = officer.gramasewaWasama.trim();
              final assignedAreas = [
                if (assignedGnDivision.isNotEmpty) assignedGnDivision,
                officer.pradeshiyaSabha,
                officer.district,
                officer.province,
              ].where((value) => value.trim().isNotEmpty).toList();

              final scopeLabel = officer.role.toLowerCase() == 'admin'
                  ? context.tr('officerScopeAllAreasAdmin')
                  : assignedGnDivision.isNotEmpty
                  ? '${context.tr('officerScopePrefix')}: $assignedGnDivision'
                  : assignedAreas.isEmpty
                  ? context.tr('officerScopeNoAreaAssigned')
                  : '${context.tr('officerScopePrefix')}: ${assignedAreas.join(' • ')}';

              final query = _search.text.toLowerCase();
              final filtered = items.where((appointment) {
                final effectiveDate =
                    appointment.scheduledDate ?? appointment.preferredDate;
                final now = DateTime.now();
                final isToday =
                    effectiveDate.year == now.year &&
                    effectiveDate.month == now.month &&
                    effectiveDate.day == now.day;

                final matchesSearch =
                    appointment.referenceNumber.toLowerCase().contains(query) ||
                    appointment.citizenName.toLowerCase().contains(query) ||
                    appointment.subject.toLowerCase().contains(query) ||
                    appointment.pradeshiyaSabha.toLowerCase().contains(query) ||
                    appointment.nic.toLowerCase().contains(query);

                final matchesFilter = switch (_filter) {
                  'attention' =>
                    appointment.status == 'Requested' ||
                        appointment.status == 'Rescheduled',
                  'today' => isToday,
                  'requested' => appointment.status == 'Requested',
                  'approved' => appointment.status == 'Approved',
                  'rescheduled' => appointment.status == 'Rescheduled',
                  'declined' => appointment.status == 'Declined',
                  'completed' => appointment.status == 'Completed',
                  _ => true,
                };

                return matchesSearch && matchesFilter;
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 450),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withAlpha(180),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(42),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('officerGnInboxTitle'),
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('officerGnInboxDescription'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withAlpha(220),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scopeLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withAlpha(210),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _statTile(
                                  context.tr('officerStatNew'),
                                  requested.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statTile(
                                  _statusFilterLabel('attention'),
                                  needsAttention.toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _statTile(
                                  _statusFilterLabel('today'),
                                  items
                                      .where((item) {
                                        final date =
                                            item.scheduledDate ??
                                            item.preferredDate;
                                        final now = DateTime.now();
                                        return date.year == now.year &&
                                            date.month == now.month &&
                                            date.day == now.day;
                                      })
                                      .length
                                      .toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.tr('officerSearchAppointmentsHint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OfficerFilterChip(
                        label: _statusFilterLabel('all'),
                        active: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('attention'),
                        active: _filter == 'attention',
                        onTap: () => setState(() => _filter = 'attention'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('today'),
                        active: _filter == 'today',
                        onTap: () => setState(() => _filter = 'today'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('requested'),
                        active: _filter == 'requested',
                        onTap: () => setState(() => _filter = 'requested'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('approved'),
                        active: _filter == 'approved',
                        onTap: () => setState(() => _filter = 'approved'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('rescheduled'),
                        active: _filter == 'rescheduled',
                        onTap: () => setState(() => _filter = 'rescheduled'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('declined'),
                        active: _filter == 'declined',
                        onTap: () => setState(() => _filter = 'declined'),
                      ),
                      OfficerFilterChip(
                        label: _statusFilterLabel('completed'),
                        active: _filter == 'completed',
                        onTap: () => setState(() => _filter = 'completed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${filtered.length} ${context.tr('officerAppointmentsFound')}',
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          context.tr('officerNoAppointmentsForArea'),
                          style: GoogleFonts.inter(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((appointment) {
                      return FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildAppointmentCard(officer, appointment),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withAlpha(220),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(UserModel officer, GnAppointment appointment) {
    final dateText = DateFormat.yMMMd().format(appointment.preferredDate);
    final isMine = appointment.assignedOfficerId == officer.id;
    final hasAssignee = appointment.assignedOfficerId.trim().isNotEmpty;
    final canAct = !hasAssignee || isMine;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.referenceNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment.citizenName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(appointment.status).withAlpha(20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusDisplayLabel(appointment.status),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(appointment.status),
                    ),
                  ),
                ),
                if (appointment.isUrgent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Urgent',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text(
              appointment.subject,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            _infoLine(Icons.person_outline_rounded, appointment.nic),
            const SizedBox(height: 6),
            _infoLine(Icons.call_rounded, appointment.phone),
            const SizedBox(height: 6),
            _infoLine(
              Icons.location_on_outlined,
              [
                appointment.pradeshiyaSabha,
                appointment.district,
              ].where((value) => value.isNotEmpty).join(' • '),
            ),
            const SizedBox(height: 6),
            _infoLine(
              Icons.calendar_month_rounded,
              '$dateText • ${appointment.preferredTimeSlot}',
            ),
            const SizedBox(height: 6),
            _infoLine(Icons.meeting_room_rounded, appointment.meetingMode),
            if (appointment.scheduledDate != null) ...[
              const SizedBox(height: 6),
              _infoLine(
                Icons.event_repeat_rounded,
                '${context.tr('scheduledFor')} ${DateFormat.yMMMd().format(appointment.scheduledDate!)}',
              ),
            ],
            if (hasAssignee) ...[
              const SizedBox(height: 6),
              _infoLine(
                Icons.badge_outlined,
                isMine ? 'Assigned to you' : 'Assigned to another officer',
              ),
            ],
            if (appointment.reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                appointment.reason,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.foreground,
                  height: 1.45,
                ),
              ),
            ],
            if (appointment.officerNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  appointment.officerNotes,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.foreground,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (appointment.status == 'Requested')
                  FilledButton(
                    onPressed: _isProcessing || !canAct
                        ? null
                        : () => _handleApprove(officer, appointment),
                    child: Text(context.tr('actionApprove')),
                  ),
                if (appointment.status == 'Requested')
                  OutlinedButton(
                    onPressed: _isProcessing || !canAct
                        ? null
                        : () => _handleReschedule(officer, appointment),
                    child: Text(context.tr('actionReschedule')),
                  ),
                if (appointment.status == 'Requested')
                  TextButton(
                    onPressed: _isProcessing || !canAct
                        ? null
                        : () => _handleDecline(officer, appointment),
                    child: Text(context.tr('actionDecline')),
                  ),
                if (appointment.status == 'Approved' ||
                    appointment.status == 'Rescheduled')
                  FilledButton.tonal(
                    onPressed: _isProcessing || !canAct
                        ? null
                        : () => _handleComplete(officer, appointment),
                    child: Text(context.tr('actionMarkCompleted')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'completed':
        return const Color(0xFF0F766E);
      case 'declined':
        return const Color(0xFFDC2626);
      case 'rescheduled':
        return const Color(0xFF2563EB);
      default:
        return AppColors.primary;
    }
  }
}
