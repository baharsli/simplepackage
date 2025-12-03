import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:pixply/env.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // layout constants
  final double _tileHeight = 82;
  final double _tileBorderRadius = 41;
  final double _overlap = 30;

  // --- Contact form state ---
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _nameC = TextEditingController();
  final _msgC = TextEditingController();
  bool _sending = false;

  final List<Map<String, String>> faqQuestions = [
    {
      "q": "What is Pixply and how does it work?",
      "a": "Pixply is a rollable 30×30 cm hybrid game board combining classic gameplay with digital interaction. It features over 50 games and works offline — just connect it via Bluetooth to the Pixply app to explore and play."
    },
    {"q": "Do I need internet to use Pixply?","a": "No. Pixply works completely offline after setup. Internet is only needed for app updates or downloading new games."},
    {"q": "How do I connect to the Pixply board via Bluetooth?","a": "Open the Pixply app, go to the Connect page , and tap 'Connect' to link your board via Bluetooth."},
    {"q": "What if the Bluetooth connection fails?","a": "Make sure Bluetooth is turned on and your board is nearby. If needed, restart Bluetooth or the Pixply app and reconnect."},
    {"q": "Which countries can I order Pixply from?","a": "Pixply ships worldwide — including the UK, Europe, the US, Canada, Australia, and more."},
    {"q": "Are shipping, taxes, or VAT included in the price?","a": "VAT is included. Shipping and local taxes will be calculated at checkout based on your location."},
    {"q": "How can I cancel my reservation?","a": "Contact our support team at support@pixply.io — we’ll handle your cancellation promptly."},
    {"q": "Do I need to pay for the games separately?","a": "No. Over 70 games come pre-loaded with Pixply. New games will be added for free or through optional updates."},
    {"q": "Can Pixply’s lights be seen clearly outdoors or in daylight?","a": "Yes. Pixply uses high-contrast LEDs visible in most daylight conditions. For best visibility, play in shaded or moderate light."},
    {"q": "Can I use my own game pieces, tokens, or checkers with Pixply?","a": "Yes. Pixply works with most standard pieces, and also includes a custom set of tokens designed for perfect fit and smooth gameplay."},
    {"q": "How much power does Pixply consume, and how is it powered?","a": "Pixply is highly energy-efficient. Power it via USB-C or a power bank — a 10,000 mAh bank provides about 10–12 hours of play."},
    {"q": "Can I customize the color of the light dots on Pixply?","a": "Yes. You can easily pick your preferred LED colors from the Pixply app for a more personal and vibrant experience."},
    {"q": "How do I change the LED display color?","a": "In the app, go to Settings → Color and select your desired hue."},
    {"q": "How do I rotate the displayed image?","a": "Open Settings → Rotation and choose 0°, 90°, 180°, or 270°."},
    {"q": "How do I launch a game on the Pixply board?","a": "From the app, select a game and tap 'Play Now' — it will appear instantly on your board."},
    {"q": "How do I reset the board after playing a game?","a": "In Settings, select 'Reset to Default' to clear the board and return to the Pixply logo."},
    {"q": "Can I upload my own images to display?","a": "This feature is coming soon in the PixStudio update."},
    {"q": "Can I clean Pixply, and how durable is it?","a": "Yes. Pixply is made of durable, flexible material. Simply wipe it gently with a soft, dry or slightly damp cloth."},
  ];
  int? expandedFAQIndex;
  final Map<int, GlobalKey> _faqExpKeys = {};
  final Map<int, double> _faqExpHeights = {};

  void _captureFaqHeight(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _faqExpKeys[index]?.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if ((_faqExpHeights[index] ?? -1) != h) {
        setState(() => _faqExpHeights[index] = h);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailC.dispose();
    _nameC.dispose();
    _msgC.dispose();
    super.dispose();
  }

  // ---------------------------
  // CONTACT FORM (send to Make)
  // ---------------------------
  Future<void> _sendContact() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _sending = true);
    try {
      final uri = Uri.parse(makeWebhookUrlContact);
      final payload = {
        'source': 'contact',
        'submitted_at': DateTime.now().toIso8601String(),
        'email': _emailC.text.trim(),
        'name': _nameC.text.trim(),
        'message': _msgC.text.trim(),
        // Optional extra metadata (add columns later if you want)
        // 'app_version': '1.0.0',
        // 'platform': Theme.of(context).platform.name,
      };

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent')),
        );
        _msgC.clear(); // keep email/name filled for convenience
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed (${res.statusCode}). Try again.')),
        );
      }
    } on SocketException catch (e) {
      // Offline / DNS resolution issues. Log internally; show friendly text.
      // ignore: avoid_print
      debugPrint('Contact form SocketException: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Check and try again.')),
      );
    } on http.ClientException catch (e) {
      debugPrint('Contact form ClientException: ${e.message} uri=${e.uri}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please try again.')),
      );
    } catch (e, st) {
      debugPrint('Contact form unexpected error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildContactForm() {
    final line = Colors.white.withValues(alpha: 0.35);
    final lineFocused = Colors.white.withValues(alpha: 0.85);

    InputDecoration deco(String label, String hint) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
            color: Colors.white, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w400),
        hintStyle: const TextStyle(
            color: Colors.white70, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w400),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line, width: 1)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: lineFocused, width: 1.2)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      );
    }

    String? emailValidator(String? v) {
      final s = (v ?? '').trim();
      if (s.isEmpty) return 'Email is required';
      final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!re.hasMatch(s)) return 'Enter a valid email';
      return null;
    }
    String? messageValidator(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Message is required';
  if (s.characters.length > 500) return 'Max 500 characters';
  return null;
}


    String? requiredValidator(String? v) =>
        (v == null || v.trim().isEmpty) ? 'This field is required' : null;
        return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Email *', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w400)),
              TextFormField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400),
                validator: emailValidator,
                decoration: deco('', 'Enter Email'),
              ),
              const SizedBox(height: 24),

              const Text('Your Name *', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w400)),
              TextFormField(
                controller: _nameC,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400),
                validator: requiredValidator,
                decoration: deco('', 'Write your name'),
              ),
              const SizedBox(height: 24),

              const Text('Your Message *', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w400)),
              TextFormField(
                controller: _msgC,
                minLines: 4,
                maxLines: 7,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400),
                validator: messageValidator,
                decoration: deco('', 'Write your message'),
                maxLength: 500,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                 inputFormatters: [LengthLimitingTextInputFormatter(500)],
  buildCounter: (
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    int? maxLength,
  }) {
    return Text(
      '$currentLength / $maxLength',
      style: const TextStyle(
        color: Colors.white70, fontFamily: 'Poppins', fontSize: 12),
    );
  },
),
              
              const SizedBox(height: 28),

              SizedBox(
                height: 82,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendContact,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _sending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Message', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqTile(String title, {required bool expanded}) {
    return Container(
      height: _tileHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF5A5A5A),
        borderRadius: BorderRadius.circular(_tileBorderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white, fontFamily: 'Poppins')),
          ),
          Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white, size: 28),
        ],
      ),
    );
  }
  Widget _buildFaqExpandedBox(Widget child) {
    // top padding is twice bottom; give text a bit more breathing room from the top
    const double topPad = 50;
    const double bottomPad = 20;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(20, topPad, 20, bottomPad),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_tileBorderRadius),
          bottomRight: Radius.circular(_tileBorderRadius),
        ),
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }

  Widget _buildFaqExpandableItem({
    required int index,
    required String title,
    required Widget expandedChild,
    required bool expanded,
    double overlap = 30, // about 30 px tucks under the question tile
  }) {
    _faqExpKeys.putIfAbsent(index, () => GlobalKey());
    if (expanded) _captureFaqHeight(index);

    final double topOffset = (_tileHeight - overlap).clamp(0, _tileHeight);
    final double expandedHeight = expanded ? (_faqExpHeights[index] ?? 0) : 0;
    final double stackHeight = expanded
        ? math.max(_tileHeight, topOffset + expandedHeight)
        : _tileHeight;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        height: stackHeight,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (expanded)
              Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                child: KeyedSubtree(
                  key: _faqExpKeys[index],
                  child: _buildFaqExpandedBox(expandedChild),
                ),
              ),
            SizedBox(
              height: _tileHeight,
              child: GestureDetector(
                onTap: () => setState(() => expandedFAQIndex = expanded ? null : index),
                child: _buildFaqTile(title, expanded: expanded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 71,
                        height: 71,
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/back.svg',
                            width: 35,
                            height: 35,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text('Help', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            // Tabs
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.greenAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(child: Text('FAQ', style: TextStyle(fontFamily: 'poppins', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white))),
                  Tab(child: Text('Contact Us', style: TextStyle(fontFamily: 'poppins', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white))),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRuleStyleSections(faqQuestions, true),
                  _buildContactForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleStyleSections(List<Map<String, String>> data, bool isFAQTab) {
    if (!isFAQTab) return _buildContactForm();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 30, bottom: 30),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final bool expanded = expandedFAQIndex == index;

        return _buildFaqExpandableItem(
          index: index,
          title: item['q']!,
          expanded: expanded,
          expandedChild: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item['a']!,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins', fontWeight: FontWeight.w400),
            ),
          ),
        );
      },
    );
  }
}
