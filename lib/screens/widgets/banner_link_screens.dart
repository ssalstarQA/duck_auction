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

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _FeatureHeaderCard(
                icon: Icons.timer_outlined,
                title: '곧 종료되는 경매를 모았어요',
                description: '놓치기 쉬운 마감 임박 상품을 빠르게 확인하고 입찰해보세요.',
              ),
              const SizedBox(height: 14),
              ...products.map((product) => ProductListTile(product: product)),
            ],
          );
        },
      ),
    );
  }
}

class AdvertisementInquiryScreen extends StatefulWidget {
  const AdvertisementInquiryScreen({super.key});

  @override
  State<AdvertisementInquiryScreen> createState() => _AdvertisementInquiryScreenState();
}

class _AdvertisementInquiryScreenState extends State<AdvertisementInquiryScreen> {
  final _shopController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedPackage = '메인 배너';

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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        children: [
          _FeatureHeaderCard(
            icon: Icons.campaign_outlined,
            title: '굿즈샵을 덕옥션에 알려보세요',
            description: '메인 배너, 카테고리 추천 영역, 신규 판매자 이벤트와 연결할 수 있어요.',
          ),
          const SizedBox(height: 14),
          _InfoPanel(
            title: '광고 상품',
            child: Column(
              children: [
                _SelectableAdPackage(
                  title: '메인 배너',
                  description: '홈 상단 배너에 상점 또는 이벤트 노출',
                  selected: _selectedPackage == '메인 배너',
                  onTap: () => setState(() => _selectedPackage = '메인 배너'),
                ),
                _SelectableAdPackage(
                  title: '카테고리 추천',
                  description: '관련 굿즈 카테고리 영역에 노출',
                  selected: _selectedPackage == '카테고리 추천',
                  onTap: () => setState(() => _selectedPackage = '카테고리 추천'),
                ),
                _SelectableAdPackage(
                  title: '판매자 프로모션',
                  description: '신규 판매자 혜택/기획전 형태로 노출',
                  selected: _selectedPackage == '판매자 프로모션',
                  onTap: () => setState(() => _selectedPackage = '판매자 프로모션'),
                ),
              ],
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: const [
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

