import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import '../utils/ui_helper.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Theme Colors
  static const Color _bg = Color(0xFFF2FBF5);
  static const Color _surface = Color(0xFFEAF7EE);
  static const Color _primaryDark = Color(0xFF1C5E3D);
  static const Color _textPrimary = Color(0xFF10231A);
  static const Color _textSecondary = Color(0xFF486252);

  @override
  bool get wantKeepAlive => true;

  List<dynamic> _banners = [];
  String? _lastBannersHash;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    _syncFromCache();
    _updateSubscription = ApiService.onDataUpdated.listen((_) => _syncFromCache());
    _refreshHomeData();
  }

  void _syncFromCache() {
    final cached = ApiService.allBanners;
    _updateUIState(cached);
  }

  void _updateUIState(List<dynamic> data) {
    if (!mounted) return;
    final newHash = ApiService.listFingerprint(data);
    if (newHash != _lastBannersHash) {
      setState(() {
        _lastBannersHash = newHash;
        _banners = data;
      });
    }
  }

  Future<void> _refreshHomeData() async {
    try {
      await ApiService.refreshCatalogIfStale(force: true);
      if (ApiService.hasActiveSession) await ApiService.syncAllUserData();
      final data = await ApiService.fetchBanners(forceRefresh: true);
      _updateUIState(data);
    } catch (e) {
      debugPrint('Home Refresh Error: $e');
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshHomeData,
          color: _primaryDark,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: 500,
            slivers: [
              // Top Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildTopBar(),
                ),
              ),
              // Search Bar
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                sliver: SliverToBoxAdapter(child: _buildSearchBar(context)),
              ),
              // Banner Slider
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _banners.isEmpty
                      ? _buildShimmerBanner()
                      : _InfiniteBannerSlider(banners: _banners),
                ),
              ),
              // Section Title
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: Text(
                    'Get Started',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _textPrimary),
                  ),
                ),
              ),
              // Main Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildListDelegate([
                    _infoCard(Icons.account_balance_rounded, const Color(0xFF2E8B57), 'Universities', 'Find your goal', () => widget.onTabChange?.call(0)),
                    _infoCard(Icons.workspace_premium_rounded, const Color(0xFF3D9E67), 'Scholarships', 'Fund studies', () => widget.onTabChange?.call(1)),
                    _infoCard(Icons.upload_file_rounded, const Color(0xFF57B97C), 'Documents', 'Ready files', () => Navigator.pushNamed(context, '/education-documents')),
                    _infoCard(Icons.track_changes_rounded, const Color(0xFF2A7D52), 'Tracking', 'Check status', () => Navigator.pushNamed(context, '/track-application')),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2E8B57), Color(0xFF78C999)]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EduKar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _textPrimary)),
              Text('Find your dream university', style: TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        showSearch(context: context, delegate: GlobalSearchDelegate());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryDark.withValues(alpha: 0.4), width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: _primaryDark, size: 20),
            SizedBox(width: 12),
            Text('Search universities, scholarships...', style: TextStyle(color: _textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDCC8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: _textSecondary), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerBanner() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFDCEFE3),
      highlightColor: const Color(0xFFF4FBF6),
      child: AspectRatio(
        aspectRatio: 1.3,
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      ),
    );
  }
}

// --- Responsive Infinite Banner Component ---
class _InfiniteBannerSlider extends StatefulWidget {
  final List<dynamic> banners;
  const _InfiniteBannerSlider({required this.banners});

  @override
  State<_InfiniteBannerSlider> createState() => _InfiniteBannerSliderState();
}

class _InfiniteBannerSliderState extends State<_InfiniteBannerSlider> {
  late PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.banners.length * 500);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_controller.hasClients) {
        _controller.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutQuart);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.35,
          child: PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final banner = widget.banners[index % widget.banners.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: UiHelper.buildImage(
                          ApiService.getUploadUrl(banner['imageUrl']),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        banner['title'] ?? '',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF10231A)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _buildDots(),
      ],
    );
  }

  Widget _buildDots() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        int activePage = 0;
        if (_controller.hasClients && widget.banners.isNotEmpty) {
          activePage = (_controller.page?.round() ?? 0) % widget.banners.length;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: activePage == index ? 20 : 6,
              decoration: BoxDecoration(
                color: activePage == index ? const Color(0xFF1C5E3D) : const Color(0xFF1C5E3D).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}

// --- Search Delegate ---
class GlobalSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _searchContent();
  @override
  Widget buildSuggestions(BuildContext context) => _searchContent();

  Widget _searchContent() {
    return const Center(child: Text("Search Universities..."));
  }
}