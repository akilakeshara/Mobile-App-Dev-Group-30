import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_page_app_bar.dart';

class GovEaseChatbotPage extends StatefulWidget {
  const GovEaseChatbotPage({super.key});

  @override
  State<GovEaseChatbotPage> createState() => _GovEaseChatbotPageState();
}

class _GovEaseChatbotPageState extends State<GovEaseChatbotPage> {
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _addBotMessage('Hello! I am GovEase Assistant. How can I help you today?', [
      'How to apply for a certificate?',
      'Track my application',
      'Contact support',
    ]);
  }

  void _addBotMessage(String text, [List<String>? options]) {
    setState(() {
      _messages.add({"isUser": false, "text": text, "options": options});
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({"isUser": true, "text": text});
    });
    
    // Simple Logic Tree responses
    Future.delayed(const Duration(milliseconds: 600), () {
      if (text.contains('certificate')) {
        _addBotMessage('To apply for a certificate, go to the "Services" tab on your dashboard and select the certificate you need. Upload required proof like your NIC or address verification.', ['Okay, thanks', 'What is the fee?']);
      } else if (text == 'Track my application') {
        _addBotMessage('You can track the progress of all your submitted documents in the "My Applications" tab securely.', ['Okay, thanks']);
      } else if (text.contains('fee')) {
        _addBotMessage('Most primary certificates have a nominal processing fee of LKR 150 - LKR 300, payable online via GovEase.', ['Okay, thanks']);
      } else if (text == 'Contact support') {
        _addBotMessage('For direct assistance, call 1919 (Government Information Center) or reach out to your local Grama Niladhari.', ['Okay, thanks']);
      } else {
        _addBotMessage('Is there anything else I can help with?', ['Track my application', 'Contact support']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientPageAppBar(
        title: 'GovEase Assistant',
        subtitle: '24/7 AI-powered support Helpdesk',
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: msg['isUser'] ? _buildUserMsg(msg['text']) : _buildBotMsg(msg['text'], msg['options']),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Type an answer or pick an option...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) _addUserMessage(val.trim());
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMsg(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(text, style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
      ),
    );
  }

  Widget _buildBotMsg(String text, List<String>? options) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border.withAlpha(50)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(text, style: GoogleFonts.inter(fontSize: 14, color: AppColors.foreground)),
          ),
          if (options != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) => ActionChip(
                backgroundColor: AppColors.primary.withAlpha(20),
                labelStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                label: Text(opt),
                side: BorderSide.none,
                onPressed: () => _addUserMessage(opt),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
