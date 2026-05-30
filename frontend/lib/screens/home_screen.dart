import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
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
        // Load offline fallback scenarios so app continues to look fully functional
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
    // Trigger scroll animation focus on input field
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

          // 2. Main Scrollable Container
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Premium Styled App Header
                SliverToBoxAdapter(child: _buildHeader(isDesktop)),

                // Selector Panels & Mode Toggles
                SliverToBoxAdapter(child: _buildControlPanel(isDesktop)),

                // Predefined Scenarios List
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRE-DEFINED SCENARIOS',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white.withOpacity(0.5),
                          ),
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
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40.0 : 24.0, 
        vertical: 32.0
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F5AF0), Color(0xFF2CB67D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.sports_hockey, // Representing the frisbee disc
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Ultimate Rules Assistant',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ultimate Frisbee Comparative Rulebook Router',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.6),
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
          // Glassmorphic Container
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
                    // Mode Switcher Toggle Tab
                    _buildModeSwitcher(),
                    const SizedBox(height: 24),
                    
                    // League Selectors Dropdowns
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
              // Animated slider selector
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
                        // Avoid same-league selection initially
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
      // Single Review League Dropdown Selector
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
      // Side-by-side Dual Selectors
      final items = [
        // Dropdown A
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
                    // Prevent duplicate selections dynamically
                    if (_selectedLeagueA == _selectedLeagueB) {
                      _selectedLeagueB = _leagues.firstWhere((l) => l != _selectedLeagueA);
                    }
                  });
                },
                color: _leagueColors[_selectedLeagueA]!,
                // Exclude currently chosen B option
                exclude: _selectedLeagueB,
              ),
            ],
          ),
        ),
        
        SizedBox(width: isDesktop ? 24 : 12),
        
        // Dynamic swap middle button
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

        // Dropdown B
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
                // Exclude currently chosen A option
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
    // Filtered options to prevent double-selection
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
                        // Category Label
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
                        // Title
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
                        // Quick short preview
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
              Text(
                'DESCRIBE THE RULES SCENARIO',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
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
          const SizedBox(height: 8),
          
          // Spacious query text field
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

          // Submit Action Button
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
              // Stylish modern wave loader
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

    // If comparing two leagues, render the dynamic split screen or tabbed view
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
                // Header badge
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
    // Parse the 3 parts from the response using robust RegEx to split cleanly
    // Expected structure:
    // 1. LEAGUE A RULING ...
    // 2. LEAGUE B RULING ...
    // 3. OBSERVER ANALYSIS ...
    
    String partA = '';
    String partB = '';
    String partAnalysis = '';

    // Attempt splitting based on explicit section headings or fallback to a general split
    final parts = _parseThreePartResponse(markdown);
    partA = parts[0];
    partB = parts[1];
    partAnalysis = parts[2];

    final colorA = _leagueColors[_selectedLeagueA] ?? const Color(0xFF7F5AF0);
    final colorB = _leagueColors[_selectedLeagueB] ?? const Color(0xFF2CB67D);

    if (isDesktop) {
      // Ocular comparative layout for Desktop/Web (side-by-side columns)
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column League A
                Expanded(
                  child: _buildGlassCard(
                    title: '$_selectedLeagueA RULING',
                    content: partA,
                    themeColor: colorA,
                  ),
                ),
                const SizedBox(width: 24),
                // Column League B
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
            // Elevated Observer analysis full-width card below
            _buildObserverCard(partAnalysis),
          ],
        ),
      );
    } else {
      // Responsive Tabbed/Stacked layout for Mobile screens
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
        child: Column(
          children: [
            // Stacked Cards for clean scrolling Mobile UX
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
    const goldColor = Color(0xFFFFD700); // Observer Gold
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

  /// Parses the three-part LLM synthesis markdown output dynamically
  List<String> _parseThreePartResponse(String markdown) {
    // We isolate sections using Regex.
    // Clean headers usually appear in LLM responses e.g.:
    // "1. LEAGUE A RULING" or "## 1. USAU RULING" or "### LEAGUE A RULING"
    // Let's search for patterns and split.

    // A list of regex headers we expect for splitting
    final RegExp leagueAHeader = RegExp(r'(1\.\s*LEAGUE\s*[AB]\s*RULING|LEAGUE\s*[AB]\s*RULING|LEAGUE\s*A\s*RULING|PART\s*1)', caseSensitive: false);
    final RegExp leagueBHeader = RegExp(r'(2\.\s*LEAGUE\s*[AB]\s*RULING|LEAGUE\s*B\s*RULING|PART\s*2)', caseSensitive: false);
    final RegExp observerHeader = RegExp(r'(3\.\s*OBSERVER\s*ANALYSIS|OBSERVER\s*ANALYSIS|SUMMARY\s*OF\s*DIFFERENCES|PART\s*3)', caseSensitive: false);

    // If headers cannot be easily matched via explicit regex splits, we look at markdown indexes
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

    // Dynamic split fallback if headers are formatted as numbers or general list items
    final listSplit = markdown.split(RegExp(r'\n(?=\d\.\s*|##+\s*\d|###+\s*LEAGUE|##+\s*LEAGUE|##+\s*OBSERVER)'));
    if (listSplit.length >= 3) {
      return [
        listSplit[0].trim(),
        listSplit[1].trim(),
        listSplit.sublist(2).join('\n\n').trim(),
      ];
    }

    // Default general split
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
