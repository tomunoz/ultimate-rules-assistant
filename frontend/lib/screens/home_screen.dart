import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scenarioScrollController = ScrollController();

  // State Management
  bool _isCompareMode = false;
  String _selectedLeagueA = 'USAU';
  String _selectedLeagueB = 'WFDF';
  
  List<Map<String, dynamic>> _scenarios = [];
  bool _isLoadingScenarios = true;
  String? _scenariosError;

  bool _isSynthesizing = false;
  Map<String, dynamic>? _synthesizedResult;
  String? _synthesisError;

  // Custom animations for scenario cards
  int _hoveredScenarioIndex = -1;

  final List<String> _leagues = ['USAU', 'WFDF', 'UFA', 'PUL'];

  // Map to hold style colors for leagues
  final Map<String, Color> _leagueColors = {
    'USAU': const Color(0xFF3F51B5), // Deep Indigo
    'WFDF': const Color(0xFF00BCD4), // Cool Cyan
    'UFA': const Color(0xFFFF9800),  // Pro Orange
    'PUL': const Color(0xFFE91E63),  // Passion Pink
  };

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    try {
      final data = await _apiService.fetchScenarios();
      setState(() {
        _scenarios = data;
        _isLoadingScenarios = false;
      });
    } catch (e) {
      setState(() {
        _scenariosError = e.toString();
        _isLoadingScenarios = false;
        _scenarios = _getOfflineFallbackScenarios();
      });
    }
  }

  Future<void> _submitQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please type a rules query or select a pre-defined scenario.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFFF25F4C),
        ),
      );
      return;
    }

    setState(() {
      _isSynthesizing = true;
      _synthesizedResult = null;
      _synthesisError = null;
    });

    final leaguesToSend = _isCompareMode 
        ? [_selectedLeagueA, _selectedLeagueB] 
        : [_selectedLeagueA];

    try {
      final result = await _apiService.queryRules(leaguesToSend, query);
      setState(() {
        _synthesizedResult = result;
        _isSynthesizing = false;
      });
    } catch (e) {
      setState(() {
        _synthesisError = e.toString().replaceAll('Exception: ', '');
        _isSynthesizing = false;
      });
    }
  }

  void _selectScenario(Map<String, dynamic> scenario) {
    setState(() {
      _queryController.text = scenario['description'] ?? '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Loaded Scenario: ${scenario['title']}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _leagueColors[_selectedLeagueA],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Securely launches external browser URLs
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $urlString'),
            backgroundColor: const Color(0xFFF25F4C),
          ),
        );
      }
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF16151E).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + Close Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Application Info',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      
                      // Metadata List
                      _buildInfoRow(
                        'Owner', 
                        'Tom Muñoz (tom-munoz.com)', 
                        isLink: true,
                        onTap: () => _launchURL('https://tom-munoz.com'),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow('Assistant', 'Google Antigravity', isLink: false),
                      const SizedBox(height: 24),
                      
                      // Rules Sources List
                      Text(
                        'RULES SOURCES',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildSourceLink('PUL Rules 2026', 'https://www.premierultimateleague.com/s/2026-PUL-Rules.pdf'),
                      const SizedBox(height: 8),
                      _buildSourceLink('UFA Rule Book 2026', 'https://watchufa.com/sites/default/files/UFA%20Rule%20Book%202026.pdf'),
                      const SizedBox(height: 8),
                      _buildSourceLink('USAU Official Rules 2026-27', 'https://usaultimate.org/wp-content/uploads/2025/12/2026-27-Official-Rules-of-Ultimate.pdf'),
                      const SizedBox(height: 8),
                      _buildSourceLink('WFDF Rules of Ultimate 2025-28', 'https://rules.wfdf.sport/wp-content/uploads/2024/12/WFDF-Rules-of-Ultimate-2025-2028.pdf'),
                      const SizedBox(height: 24),

                      // Known Issues List
                      Text(
                        'KNOWN ISSUES',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildKnownIssueRow('1', 'Sometimes how the scenario or question is worded can confuse the AI. Try different wording to see if that helps.'),
                      _buildKnownIssueRow('2', 'The solution sometimes has issues with content that is not clearly formatted/structured.'),
                      _buildKnownIssueRow('3', 'The solution may have issues with images embedded in the rules documents.'),
                      const SizedBox(height: 16),
                      
                      // Email Link
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _launchURL('mailto:tom.o.munoz@gmail.com'),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(text: '*Drop Tom an email ('),
                                TextSpan(
                                  text: 'tom.o.munoz@gmail.com',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF2CB67D),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ') if you experience a situation that you believe is incorrect or not behaving properly.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKnownIssueRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF7F5AF0),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLink = false, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF7F5AF0),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        isLink
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2CB67D),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              )
            : Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
      ],
    );
  }

  Widget _buildSourceLink(String name, String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.black.withOpacity(0.2),
        child: InkWell(
          onTap: () => _launchURL(url),
          hoverColor: const Color(0xFF7F5AF0).withOpacity(0.08),
          splashColor: const Color(0xFF7F5AF0).withOpacity(0.15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: Color(0xFF2CB67D)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.firaCode(
                          fontSize: 10,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(bool isDesktop) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40.0 : 24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0B10).withOpacity(0.82),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo + App Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7F5AF0), Color(0xFF2CB67D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_hockey,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Ultimate Rules Assistant',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              
              // Custom styled Info Button
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Material(
                  color: Colors.white.withOpacity(0.04),
                  child: InkWell(
                    onTap: _showInfoDialog,
                    hoverColor: const Color(0xFF7F5AF0).withOpacity(0.12),
                    splashColor: const Color(0xFF7F5AF0).withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            'Info',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0B10),
      body: Stack(
        children: [
          // 1. Sleek Gradient Backdrop Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7F5AF0).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -50,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2CB67D).withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // 2. Main Layout (Sticky Header + Scrollable Content underneath)
          SafeArea(
            child: Column(
              children: [
                _buildStickyHeader(isDesktop),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Space under header for visual breathing room
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // Selector Panels & Mode Toggles
                      SliverToBoxAdapter(child: _buildControlPanel(isDesktop)),

                      // Predefined Scenarios List
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Prominent Header with Left Accent Bar
                              Row(
                                children: [
                                  Container(
                                    width: 3.5,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: _leagueColors[_selectedLeagueA] ?? const Color(0xFF7F5AF0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PRE-DEFINED SCENARIOS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildScenariosList(),
                            ],
                          ),
                        ),
                      ),

                      // Query Text Area Input
                      SliverToBoxAdapter(child: _buildQueryInputSection(isDesktop)),

                      // Output Display Panel
                      SliverToBoxAdapter(child: _buildOutputSection(isDesktop)),
                      
                      // Footer
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Ultimate Rules Assistant RAG System • v1.0.0',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isDesktop) {
    final spacing = isDesktop ? 40.0 : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing, vertical: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Column(
                  children: [
                    _buildModeSwitcher(),
                    const SizedBox(height: 24),
                    _buildLeagueSelectors(isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: _isCompareMode ? tabWidth : 0,
                child: Container(
                  width: tabWidth,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isCompareMode 
                        ? [const Color(0xFF2CB67D).withOpacity(0.8), const Color(0xFF00BCD4).withOpacity(0.8)]
                        : [const Color(0xFF7F5AF0).withOpacity(0.8), const Color(0xFF8F6AFF).withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isCompareMode = false),
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 18,
                              color: !_isCompareMode ? Colors.white : Colors.white60,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Single Review',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: !_isCompareMode ? Colors.white : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _isCompareMode = true;
                        if (_selectedLeagueA == _selectedLeagueB) {
                          _selectedLeagueB = _leagues.firstWhere((l) => l != _selectedLeagueA);
                        }
                      }),
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.compare_arrows,
                              size: 18,
                              color: _isCompareMode ? Colors.white : Colors.white60,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Compare Leagues',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: _isCompareMode ? Colors.white : Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeagueSelectors(bool isDesktop) {
    if (!_isCompareMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECT TARGET RULEBOOK',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildLeagueDropdown(
            value: _selectedLeagueA,
            onChanged: (val) => setState(() => _selectedLeagueA = val!),
            color: _leagueColors[_selectedLeagueA]!,
          ),
        ],
      );
    } else {
      final items = [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEAGUE A',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildLeagueDropdown(
                value: _selectedLeagueA,
                onChanged: (val) {
                  setState(() {
                    _selectedLeagueA = val!;
                    if (_selectedLeagueA == _selectedLeagueB) {
                      _selectedLeagueB = _leagues.firstWhere((l) => l != _selectedLeagueA);
                    }
                  });
                },
                color: _leagueColors[_selectedLeagueA]!,
                exclude: _selectedLeagueB,
              ),
            ],
          ),
        ),
        
        SizedBox(width: isDesktop ? 24 : 12),
        
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: IconButton(
            icon: const Icon(Icons.swap_horiz, color: Colors.white60),
            onPressed: () {
              setState(() {
                final temp = _selectedLeagueA;
                _selectedLeagueA = _selectedLeagueB;
                _selectedLeagueB = temp;
              });
            },
          ),
        ),
        
        SizedBox(width: isDesktop ? 24 : 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEAGUE B',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildLeagueDropdown(
                value: _selectedLeagueB,
                onChanged: (val) {
                  setState(() {
                    _selectedLeagueB = val!;
                  });
                },
                color: _leagueColors[_selectedLeagueB]!,
                exclude: _selectedLeagueA,
              ),
            ],
          ),
        ),
      ];

      return isDesktop 
          ? Row(children: items) 
          : Row(children: items);
    }
  }

  Widget _buildLeagueDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
    required Color color,
    String? exclude,
  }) {
    final filteredLeagues = _leagues.where((l) => l != exclude).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF16151E),
          icon: Icon(Icons.keyboard_arrow_down, color: color),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          onChanged: onChanged,
          items: filteredLeagues.map((String league) {
            final lColor = _leagueColors[league] ?? Colors.white;
            return DropdownMenuItem<String>(
              value: league,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    league,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScenariosList() {
    if (_isLoadingScenarios) {
      return SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_leagueColors[_selectedLeagueA]!),
          ),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        controller: _scenarioScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _scenarios.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final s = _scenarios[index];
          final isHovered = _hoveredScenarioIndex == index;
          
          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredScenarioIndex = index),
            onExit: (_) => setState(() => _hoveredScenarioIndex = -1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 250,
              margin: const EdgeInsets.only(right: 16),
              transform: isHovered 
                  ? (Matrix4.identity()..translate(0, -6, 0))
                  : Matrix4.identity(),
              child: GestureDetector(
                onTap: () => _selectScenario(s),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHovered 
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHovered 
                            ? _leagueColors[_selectedLeagueA]!.withOpacity(0.4)
                            : Colors.white.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_leagueColors[_selectedLeagueA] ?? Colors.deepPurple).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (s['category'] ?? 'General').toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _leagueColors[_selectedLeagueA],
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          s['title'] ?? 'Scenario',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['description'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQueryInputSection(bool isDesktop) {
    final padding = isDesktop ? 40.0 : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: _leagueColors[_selectedLeagueA] ?? const Color(0xFF7F5AF0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DESCRIBE THE RULES SCENARIO',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_queryController.text.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _queryController.clear()),
                  child: Text(
                    'Clear Text',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFF25F4C),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: TextField(
              controller: _queryController,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(20),
                hintText: 'e.g., During a pull, the disc rolls out of bounds. The offense signals brick...',
                hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSynthesizing ? null : _submitQuery,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompareMode ? const Color(0xFF2CB67D) : const Color(0xFF7F5AF0),
                disabledBackgroundColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSynthesizing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isCompareMode ? const Color(0xFF2CB67D) : const Color(0xFF7F5AF0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'RAG Route & LLM Synthesis Active...',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCompareMode ? Icons.compare_arrows : Icons.search,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isCompareMode 
                              ? 'EXECUTE DUAL COMPARISON RAG'
                              : 'EXECUTE SINGLE LEAGUE RAG',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                            letterSpacing: 1.0,
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

  Widget _buildOutputSection(bool isDesktop) {
    final padding = isDesktop ? 40.0 : 24.0;

    if (_isSynthesizing) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 40),
        child: Center(
          child: Column(
            children: [
              const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7F5AF0)),
              ),
              const SizedBox(height: 20),
              Text(
                'Programmatically isolating rulebook PDFs & synthesizing answer...',
                style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_synthesisError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF25F4C).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF25F4C).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFF25F4C), size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RAG Routing Synthesis Failed',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFF25F4C),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _synthesisError!,
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_synthesizedResult == null) {
      return const SizedBox.shrink();
    }

    final String responseMarkdown = _synthesizedResult!['response'] ?? '';

    if (_isCompareMode) {
      return _buildComparativeOutput(responseMarkdown, isDesktop, padding);
    } else {
      return _buildSingleOutput(responseMarkdown, padding);
    }
  }

  Widget _buildSingleOutput(String markdown, double padding) {
    final activeColor = _leagueColors[_selectedLeagueA] ?? const Color(0xFF7F5AF0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeColor.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: activeColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'OFFICIAL RULING SUMMARY: $_selectedLeagueA',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: activeColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white10),
                MarkdownBody(
                  data: markdown,
                  styleSheet: _getCustomMarkdownStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparativeOutput(String markdown, bool isDesktop, double padding) {
    String partA = '';
    String partB = '';
    String partAnalysis = '';

    final parts = _parseThreePartResponse(markdown);
    partA = parts[0];
    partB = parts[1];
    partAnalysis = parts[2];

    final colorA = _leagueColors[_selectedLeagueA] ?? const Color(0xFF7F5AF0);
    final colorB = _leagueColors[_selectedLeagueB] ?? const Color(0xFF2CB67D);

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildGlassCard(
                    title: '$_selectedLeagueA RULING',
                    content: partA,
                    themeColor: colorA,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildGlassCard(
                    title: '$_selectedLeagueB RULING',
                    content: partB,
                    themeColor: colorB,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildObserverCard(partAnalysis),
          ],
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Column(
          children: [
            _buildGlassCard(
              title: '$_selectedLeagueA RULING',
              content: partA,
              themeColor: colorA,
            ),
            const SizedBox(height: 16),
            _buildGlassCard(
              title: '$_selectedLeagueB RULING',
              content: partB,
              themeColor: colorB,
            ),
            const SizedBox(height: 16),
            _buildObserverCard(partAnalysis),
          ],
        ),
      );
    }
  }

  Widget _buildGlassCard({
    required String title,
    required String content,
    required Color themeColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeColor.withOpacity(0.25), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: themeColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: themeColor,
                      letterSpacing: 1.0,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: Colors.white10),
              MarkdownBody(
                data: content.isNotEmpty ? content : '_No ruling text retrieved._',
                styleSheet: _getCustomMarkdownStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObserverCard(String content) {
    const goldColor = Color(0xFFFFD700);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                goldColor.withOpacity(0.04),
                const Color(0xFFF25F4C).withOpacity(0.03)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: goldColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology, color: goldColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'EXPERT OBSERVER COMPARATIVE ANALYSIS',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: goldColor,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: Colors.white10),
              MarkdownBody(
                data: content.isNotEmpty ? content : '_Analysis summary pending._',
                styleSheet: _getCustomMarkdownStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _getCustomMarkdownStyle() {
    return MarkdownStyleSheet(
      p: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.5),
      h1: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      h2: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
      h3: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      strong: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
      listBullet: GoogleFonts.outfit(color: const Color(0xFF7F5AF0)),
      code: GoogleFonts.firaCode(
        color: const Color(0xFF2CB67D),
        backgroundColor: Colors.white.withOpacity(0.05),
        fontSize: 13,
      ),
      blockquote: GoogleFonts.outfit(color: Colors.white70, fontStyle: FontStyle.italic),
      blockquoteDecoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: const Border(left: BorderSide(color: Color(0xFF7F5AF0), width: 4)),
      ),
    );
  }

  List<String> _parseThreePartResponse(String markdown) {
    int idxA = markdown.toLowerCase().indexOf('league a ruling');
    if (idxA == -1) idxA = markdown.toLowerCase().indexOf('1. ');
    if (idxA == -1) idxA = 0;

    int idxB = markdown.toLowerCase().indexOf('league b ruling');
    if (idxB == -1) idxB = markdown.toLowerCase().indexOf('2. ');
    
    int idxObs = markdown.toLowerCase().indexOf('observer analysis');
    if (idxObs == -1) idxObs = markdown.toLowerCase().indexOf('summary of differences');
    if (idxObs == -1) idxObs = markdown.toLowerCase().indexOf('3. ');

    try {
      if (idxB != -1 && idxObs != -1 && idxA < idxB && idxB < idxObs) {
        final part1 = markdown.substring(idxA, idxB).trim();
        final part2 = markdown.substring(idxB, idxObs).trim();
        final part3 = markdown.substring(idxObs).trim();
        return [part1, part2, part3];
      }
    } catch (_) {}

    final listSplit = markdown.split(RegExp(r'\n(?=\d\.\s*|##+\s*\d|###+\s*LEAGUE|##+\s*LEAGUE|##+\s*OBSERVER)'));
    if (listSplit.length >= 3) {
      return [
        listSplit[0].trim(),
        listSplit[1].trim(),
        listSplit.sublist(2).join('\n\n').trim(),
      ];
    }

    final length = markdown.length;
    return [
      markdown.substring(0, (length * 0.35).toInt()),
      markdown.substring((length * 0.35).toInt(), (length * 0.70).toInt()),
      markdown.substring((length * 0.70).toInt()),
    ];
  }

  List<Map<String, dynamic>> _getOfflineFallbackScenarios() {
    return [
      {
        'id': 'fallback_1',
        'title': 'Double Team Call',
        'category': 'Marking Violations',
        'description': 'Defender A is stalling the thrower. Defender B is standing 2 meters away blocking the open side break throw, but is not actively guarding anyone else. Thrower calls Double Team.',
      },
      {
        'id': 'fallback_2',
        'title': 'Brick on Pull Out-of-Bounds',
        'category': 'Field Setup & Pulls',
        'description': 'A pull lands completely out of bounds on the sideline without touching anyone. The receiving team calls a Brick. Where is the brick mark located, and does Beach Ultimate differ?',
      },
      {
        'id': 'fallback_3',
        'title': 'Receiving Foul in Endzone',
        'category': 'Fouls & Scoring',
        'description': 'Offense leaps to catch in attacking endzone. Defender hits them mid-air causing a drop. Offense calls foul, defense contests. What is the restart ruling?',
      },
    ];
  }
}
