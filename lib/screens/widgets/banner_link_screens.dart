part of '../home_screen.dart';

class EndingSoonAuctionsScreen extends StatelessWidget {
  const EndingSoonAuctionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('마감 임박 경매', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ValueListenableBuilder<List<ProductItem>>(
        valueListenable: DuckAuctionStore.registeredAuctions,
        builder: (context, registeredAuctions, _) {
          final products = [
            ...registeredAuctions,
            ...HomeTab.popularProducts.reversed,
            ...HomeTab.recentProducts,
          ];

          return _FilteredAuctionListView(
            products: products,
            initialSort: _AuctionSort.deadline,
            emptyText: '마감 임박 경매가 없어요',
          );
        },
      ),
    );
  }
}

class AdvertisementInquiryScreen extends StatefulWidget {
  /// 이 문의가 어떤 광고 상품에 대한 것인지예요. 홈 배너에 따라 '메인 배너' 또는
  /// '카테고리 추천'으로 들어와, 각 상품 전용 문의로 분리돼요.
  final String adProduct;

  const AdvertisementInquiryScreen({super.key, this.adProduct = '메인 배너'});

  @override
  State<AdvertisementInquiryScreen> createState() => _AdvertisementInquiryScreenState();
}

class _AdvertisementInquiryScreenState extends State<AdvertisementInquiryScreen> {
  final _shopController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();

  String get _productDescription => widget.adProduct == '카테고리 추천'
      ? '관련 굿즈 카테고리 영역에 상점·상품을 노출해요.'
      : '홈 상단 메인 배너에 상점·상품을 노출해요.';

  @override
  void dispose() {
    _shopController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitInquiry() {
    if (_shopController.text.trim().isEmpty || _contactController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상점명과 연락처를 입력해주세요.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('광고 문의가 접수되었어요. 다음 단계에서 서버 저장을 연결할 예정이에요.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('광고 문의', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _submitInquiry,
            child: const Text('광고 문의 접수하기', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
            padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeatureHeaderCard(
                  icon: Icons.campaign_outlined,
                  title: '굿즈샵·업체를 덕옥션에 알려보세요',
                  description: '${widget.adProduct} 광고 문의예요. (업체 대상)',
                ),
                const SizedBox(height: 14),
                _InfoPanel(
                  title: '광고 상품',
                  child: _SelectableAdPackage(
                    title: widget.adProduct,
                    description: _productDescription,
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 14),
                _InfoPanel(
                  title: '문의 정보',
                  child: Column(
                    children: [
                      _SimpleInput(controller: _shopController, label: '상점명 / 담당자명', hint: '예: 별별굿즈'),
                      const SizedBox(height: 10),
                      _SimpleInput(controller: _contactController, label: '연락처', hint: '이메일 또는 휴대폰 번호'),
                      const SizedBox(height: 10),
                      _SimpleInput(
                        controller: _messageController,
                        label: '문의 내용',
                        hint: '홍보하고 싶은 상품, 기간, 예산 등을 적어주세요.',
                        maxLines: 5,
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
}

class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('이벤트', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ResponsiveContentBounds(
            maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
            padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 24),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeatureHeaderCard(
                  icon: Icons.card_giftcard_outlined,
                  title: '덕옥션 이벤트',
                  description: '판매자와 구매자 모두 참여할 수 있는 혜택을 준비하고 있어요.',
                ),
                SizedBox(height: 14),
                _EventCard(
                  title: '신규 판매자 환영 이벤트',
                  period: '상시 진행 예정',
                  description: '첫 경매 등록 수수료 혜택과 판매자 뱃지를 준비 중이에요.',
                  badge: '판매자',
                ),
                _EventCard(
                  title: '첫 입찰 응원 혜택',
                  period: '오픈 베타 예정',
                  description: '처음 입찰하는 회원에게 알림/쿠폰 혜택을 제공하는 이벤트예요.',
                  badge: '구매자',
                ),
                _EventCard(
                  title: '마감 임박 알림 이벤트',
                  period: '준비 중',
                  description: '관심상품의 경매 마감 전에 알림을 받을 수 있는 기능과 연결할 예정이에요.',
                  badge: '알림',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureHeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureHeaderCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFF334155), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(height: 1.35, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SelectableAdPackage extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableAdPackage({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _SimpleInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String title;
  final String period;
  final String description;
  final String badge;

  const _EventCard({
    required this.title,
    required this.period,
    required this.description,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              Text(period, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Color(0xFF6B7280), height: 1.4, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 해덕질(해적+덕질) 이벤트 화면
//
// Firestore 컬렉션 `haedeokjil`에서 문서를 읽어와 "실루엣 → 공개 시간이 되면
// 상품 노출" 로직을 클라이언트에서 처리해요. 문서 필드:
//   - section    : 'this'(이번주 3개) | 'next'(다음주 큰 실루엣)  기본값 'this'
//   - order      : 정렬 순서 (숫자, 작을수록 먼저)
//   - slotLabel  : '월요일 11시' 같은 라벨
//   - revealAt   : Timestamp — 이 시간이 지나면 실루엣이 상품으로 바뀜
//   - productId  : products 컬렉션의 문서 id (공개 후 탭하면 상세로 이동)
//   - title      : 공개 후 보여줄 상품 이름(선택)
//   - imageUrl   : 공개 후 보여줄 이미지(선택)
//   - startPrice : 시작가(기본 1000)
// ─────────────────────────────────────────────────────────────────────────

class _HaedeokjilDrop {
  final String id;
  final String? productId;
  final String slotLabel;
  final DateTime? revealAt;
  final String title;
  final String imageUrl;
  final int startPrice;
  final String section; // 'this' | 'next'
  final int order;

  const _HaedeokjilDrop({
    required this.id,
    this.productId,
    required this.slotLabel,
    this.revealAt,
    this.title = '',
    this.imageUrl = '',
    this.startPrice = 1000,
    this.section = 'this',
    this.order = 0,
  });

  factory _HaedeokjilDrop.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawReveal = data['revealAt'];
    DateTime? revealAt;
    if (rawReveal is Timestamp) {
      revealAt = rawReveal.toDate();
    }
    final slot = (data['slotLabel'] as String?)?.trim() ?? '';
    return _HaedeokjilDrop(
      id: doc.id,
      productId: (data['productId'] as String?)?.trim(),
      slotLabel: slot.isNotEmpty ? slot : '공개 예정',
      revealAt: revealAt,
      title: (data['title'] as String?)?.trim() ?? '',
      imageUrl: (data['imageUrl'] as String?)?.trim() ?? '',
      startPrice: (data['startPrice'] as num?)?.toInt() ?? 1000,
      section: (data['section'] as String?)?.trim() == 'next' ? 'next' : 'this',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isRevealed {
    final r = revealAt;
    if (r == null) return false;
    return !DateTime.now().isBefore(r);
  }
}

class HaedeokjilScreen extends StatefulWidget {
  const HaedeokjilScreen({super.key});

  @override
  State<HaedeokjilScreen> createState() => _HaedeokjilScreenState();
}

class _HaedeokjilScreenState extends State<HaedeokjilScreen> {
  static const Color _navy = Color(0xFF0C1B38);
  static const Color _gold = Color(0xFFC99A3B);

  Timer? _ticker;
  bool _alarmOn = false;
  bool _alarmBusy = false;
  bool _opening = false;

  final Stream<QuerySnapshot<Map<String, dynamic>>> _dropsStream =
      FirebaseFirestore.instance.collection('haedeokjil').orderBy('order').snapshots();

  @override
  void initState() {
    super.initState();
    // 1초마다 화면을 갱신해 카운트다운을 흐르게 하고, 공개 시각이 지나면
    // 실루엣을 자동으로 상품으로 바꿔요.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadAlarmState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadAlarmState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('haedeokjilAlerts')
          .doc(user.uid)
          .get();
      final on = (doc.data()?['on'] as bool?) ?? false;
      if (mounted) setState(() => _alarmOn = on);
    } catch (_) {
      // 조용히 무시 — 알람 상태는 부가 기능이라 화면을 막지 않아요.
    }
  }

  Future<void> _toggleAlarm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('알람을 받으려면 먼저 로그인해주세요.');
      return;
    }
    if (_alarmBusy) return;
    setState(() => _alarmBusy = true);
    final next = !_alarmOn;
    final ref = FirebaseFirestore.instance.collection('haedeokjilAlerts').doc(user.uid);
    try {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'on': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => _alarmOn = next);
      _snack(next ? '해덕질 오픈 시간에 알려드릴게요! 🐥' : '해덕질 알람을 껐어요.');
    } catch (_) {
      _snack('잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _alarmBusy = false);
    }
  }

  Future<void> _openDrop(_HaedeokjilDrop drop) async {
    if (!drop.isRevealed) {
      _snack('${drop.slotLabel}에 공개돼요! 조금만 기다려주세요 🐥');
      return;
    }
    final pid = drop.productId;
    if (pid == null || pid.isEmpty) {
      _snack('공개됐어요! 상품 연결을 준비 중이에요.');
      return;
    }
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, isEqualTo: pid)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        _snack('상품을 찾지 못했어요. 잠시 후 다시 시도해주세요.');
        return;
      }
      final product = ProductItem.fromFirestore(snapshot.docs.first);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    } catch (_) {
      _snack('상품을 여는 중 문제가 생겼어요.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _remainingText(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return '공개됨';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (d > 0) return '$d일 $h시간 후 공개';
    if (h > 0) return '$h시간 $m분 후 공개';
    if (m > 0) return '$m분 $s초 후 공개';
    return '$s초 후 공개';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('이번 주의 해덕질', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _dropsStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final drops = docs.map(_HaedeokjilDrop.fromDoc).toList();
          final thisWeek = drops.where((d) => d.section == 'this').toList();
          final nextWeek = drops.where((d) => d.section == 'next').toList();

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              ResponsiveContentBounds(
                maxWidth: context.responsive(phone: double.infinity, tablet: 640.0),
                padding: EdgeInsets.fromLTRB(context.pagePadding, 14, context.pagePadding, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 18),
                    const _HaedeokjilSectionTitle(
                      emoji: '🏴‍☠️',
                      title: '이번주 해덕질',
                      subtitle: '매주 월·수·금 오전 11시 오픈!',
                    ),
                    const SizedBox(height: 12),
                    if (thisWeek.isEmpty)
                      _buildEmptyThisWeek()
                    else
                      _buildThisWeekGrid(thisWeek),
                    const SizedBox(height: 24),
                    const _HaedeokjilSectionTitle(
                      emoji: '🔭',
                      title: '다음주 해덕질은?',
                      subtitle: '일요일 오전 11시에 실루엣이 공개돼요!',
                    ),
                    const SizedBox(height: 12),
                    _buildNextWeek(nextWeek),
                    const SizedBox(height: 22),
                    _buildAlarmButton(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navy, Color(0xFF16305C)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _navy.withOpacity(0.25), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withOpacity(0.5)),
            ),
            child: const Text(
              '5주 동안 이어지는 이벤트',
              style: TextStyle(color: Color(0xFFF2D79B), fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '🏴‍☠️ 해덕질',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          const Text(
            '해적이니까 싸게 가져가야지!\n모든 상품 최저가 경매 시작가 단 1,000원!',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, height: 1.45, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekGrid(List<_HaedeokjilDrop> drops) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3개까지는 한 줄에, 그 이상이면 자동 줄바꿈.
        const spacing = 10.0;
        final int columns = drops.length >= 3 ? 3 : (drops.length < 1 ? 1 : drops.length);
        final double itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: drops
              .map((d) => SizedBox(
                    width: itemWidth,
                    child: _dropCard(d, big: false),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildNextWeek(List<_HaedeokjilDrop> drops) {
    if (drops.isEmpty) {
      return _bigSilhouettePlaceholder();
    }
    return Column(
      children: [
        for (final d in drops)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _dropCard(d, big: true),
          ),
      ],
    );
  }

  Widget _dropCard(_HaedeokjilDrop drop, {required bool big}) {
    final revealed = drop.isRevealed;
    final double height = big ? 190 : 158;

    return GestureDetector(
      onTap: () => _openDrop(drop),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: revealed ? Colors.white : _navy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: revealed ? const Color(0xFFE5E7EB) : _gold.withOpacity(0.35),
          ),
          boxShadow: [
            if (revealed)
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: revealed ? _revealedContent(drop, big: big) : _silhouetteContent(drop, big: big),
      ),
    );
  }

  Widget _silhouetteContent(_HaedeokjilDrop drop, {required bool big}) {
    final reveal = drop.revealAt;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Text(
            '?',
            style: TextStyle(
              color: _gold.withOpacity(0.55),
              fontWeight: FontWeight.w900,
              fontSize: big ? 74 : 52,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                drop.slotLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                reveal == null ? '공개 준비 중' : _remainingText(reveal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _gold.withOpacity(0.95), fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _revealedContent(_HaedeokjilDrop drop, {required bool big}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (drop.imageUrl.isNotEmpty)
                Image.network(
                  drop.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imageFallback(),
                )
              else
                _imageFallback(),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('OPEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                drop.title.isNotEmpty ? drop.title : drop.slotLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '시작가 ${_formatWon(drop.startPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _navy),
                  ),
                  const Spacer(),
                  if (drop.productId != null && drop.productId!.isNotEmpty)
                    const Text('입찰하러 가기 ›', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, color: _gold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imageFallback() {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Text('🐥', style: TextStyle(fontSize: 40)),
    );
  }

  Widget _bigSilhouettePlaceholder() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.35)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text('?', style: TextStyle(color: _gold.withOpacity(0.55), fontWeight: FontWeight.w900, fontSize: 74)),
          ),
          const Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Text(
              '다음주 상품은 일요일 11시에 공개돼요!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyThisWeek() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Text('🏴‍☠️', style: TextStyle(fontSize: 34)),
          SizedBox(height: 8),
          Text('이번주 해덕질을 준비 중이에요', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          SizedBox(height: 4),
          Text(
            '월·수·금 오전 11시에 하나씩 공개돼요.\n알람을 켜두면 오픈 시간에 알려드릴게요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, height: 1.4, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmButton() {
    return FilledButton.icon(
      onPressed: _alarmBusy ? null : _toggleAlarm,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        backgroundColor: _alarmOn ? const Color(0xFFEEF2F9) : _navy,
        foregroundColor: _alarmOn ? _navy : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(_alarmOn ? Icons.notifications_active : Icons.notifications_none),
      label: Text(
        _alarmOn ? '해덕질 알람 켜짐 (끄기)' : '해덕질 알람받기',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  String _formatWon(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }
}

class _HaedeokjilSectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _HaedeokjilSectionTitle({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}

