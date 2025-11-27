import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/user_service.dart';
import '../../core/services/purchase_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../auth/login_screen.dart';
import '../../core/services/auth_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _authService = AuthService();
  final _purchaseService = PurchaseService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Guard: If not logged in, redirect to login screen
    if (_authService.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        )
            .then((_) {
          if (mounted) {
            setState(() {});
          }
        });
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: StreamBuilder<UserData?>(
        stream: UserService.instance.currentUserData,
        builder: (context, snapshot) {
          final userData = snapshot.data;
          final isPro = userData?.hasValidSubscription ?? false;

          return CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: Responsive.scaleHeight(context, 200),
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Premium',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primaryContainer,
                          Colors.amber,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative shapes
                        Positioned(
                          top: -50,
                          right: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -30,
                          left: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                        // Content
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPro
                                    ? Icons.verified_rounded
                                    : Icons.diamond_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                              SizedBox(
                                  height: Responsive.scaleHeight(context, 12)),
                              Text(
                                isPro ? 'You\'re Pro!' : 'Unlock Premium',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (userData != null) ...[
                                SizedBox(
                                    height: Responsive.scaleHeight(context, 8)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        Responsive.scaleWidth(context, 16),
                                    vertical:
                                        Responsive.scaleHeight(context, 8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.stars_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(
                                          width: Responsive.scaleWidth(
                                              context, 8)),
                                      Text(
                                        '${userData.credits.toStringAsFixed(1)} Credits',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: Responsive.padding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (userData == null)
                        _buildSignInPrompt(context, theme)
                      else ...[
                        if (!isPro) ...[
                          // Subscription Plans
                          _buildSectionHeader(
                              context, theme, 'Choose Your Plan'),
                          SizedBox(height: Responsive.scaleHeight(context, 16)),
                          _buildSubscriptionPlans(context, theme),
                          SizedBox(height: Responsive.scaleHeight(context, 32)),

                          // Premium Features
                          _buildFeaturesSection(context, theme),
                          SizedBox(height: Responsive.scaleHeight(context, 32)),
                        ],

                        // Credit Packages
                        _buildSectionHeader(context, theme, 'Buy Credits'),
                        SizedBox(height: Responsive.scaleHeight(context, 8)),
                        Text(
                          'Pick the credit pack that fits your needs. Credits never expire.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 16)),
                        _buildCreditPackages(context, theme, userData),
                        SizedBox(height: Responsive.scaleHeight(context, 24)),
                      ],
                    ],
                  ),
                ),
              ),

              // Banner Ad
              const SliverToBoxAdapter(
                child: BannerAdWidget(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_circle_rounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          SizedBox(height: Responsive.scaleHeight(context, 16)),
          Text(
            'Sign in to access Premium features',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.scaleHeight(context, 24)),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.scaleWidth(context, 32),
                vertical: Responsive.scaleHeight(context, 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, ThemeData theme, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: Responsive.scaleWidth(context, 12)),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context, ThemeData theme) {
    final features = [
      {
        'icon': Icons.verified_rounded,
        'title': 'Pro Badge',
        'description': 'Show your Pro status',
        'color': Colors.amber,
      },
      {
        'icon': Icons.block_rounded,
        'title': 'No Ads',
        'description': 'Remove all advertisements',
        'color': theme.colorScheme.primary,
      },
      {
        'icon': Icons.image_rounded,
        'title': 'No Watermarks',
        'description': 'Clean images without watermarks',
        'color': Colors.blue,
      },
      {
        'icon': Icons.stars_rounded,
        'title': 'Premium Credits',
        'description': 'Recurring credits with every plan',
        'color': Colors.purple,
      },
      {
        'icon': Icons.download_rounded,
        'title': 'Unlimited Downloads',
        'description': 'Download as many images as you want',
        'color': Colors.green,
      },
      {
        'icon': Icons.support_agent_rounded,
        'title': 'Priority Support',
        'description': 'Get priority customer support',
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, theme, 'Premium Features'),
        SizedBox(height: Responsive.scaleHeight(context, 16)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: Responsive.scaleWidth(context, 12),
            mainAxisSpacing: Responsive.scaleHeight(context, 12),
            childAspectRatio: 1.1,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (feature['color'] as Color).withOpacity(0.1),
                    (feature['color'] as Color).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (feature['color'] as Color).withOpacity(0.2),
                ),
              ),
              padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
                    decoration: BoxDecoration(
                      color: (feature['color'] as Color).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 28,
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 12)),
                  Text(
                    feature['title'] as String,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 4)),
                  Text(
                    feature['description'] as String,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubscriptionPlans(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        _buildPlanCard(
          context,
          theme,
          planName: 'Monthly',
          price: '\$10',
          period: '/month',
          productId: 'monthly_10',
          features: [
            'Unlock all premium features',
            'Ad-free experience',
            'Cancel anytime',
          ],
          isPopular: false,
        ),
        SizedBox(height: Responsive.scaleHeight(context, 16)),
        _buildPlanCard(
          context,
          theme,
          planName: 'Quarterly',
          price: '\$35',
          period: '/quarter',
          productId: 'quarterly_35',
          features: [
            'Unlock all premium features',
            'Priority support',
            'Save compared to monthly',
          ],
          isPopular: true,
        ),
        SizedBox(height: Responsive.scaleHeight(context, 16)),
        _buildPlanCard(
          context,
          theme,
          planName: 'Half-Yearly',
          price: '\$75',
          period: '/6 months',
          productId: 'halfly_75',
          features: [
            'Unlock all premium features',
            'Priority email support',
            'Great for long-term creators',
          ],
          isPopular: false,
        ),
        SizedBox(height: Responsive.scaleHeight(context, 16)),
        _buildPlanCard(
          context,
          theme,
          planName: 'Yearly',
          price: '\$200',
          period: '/year',
          productId: 'yearly_200',
          features: [
            'Unlock all premium features',
            'Priority support',
            'Best long-term value',
          ],
          isPopular: false,
        ),
      ],
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    ThemeData theme, {
    required String planName,
    required String price,
    required String period,
    required String productId,
    required List<String> features,
    bool isPopular = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isPopular
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.orange.withOpacity(0.2),
                ],
              )
            : null,
        color: isPopular ? null : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular
              ? Colors.amber.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: () async {
          try {
            await _purchaseService.buySubscription(productId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Purchase initiated!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Purchase failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            planName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (isPopular) ...[
                            SizedBox(width: Responsive.scaleWidth(context, 8)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.scaleWidth(context, 8),
                                vertical: Responsive.scaleHeight(context, 4),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'POPULAR',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 4)),
                      Text(
                        period,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isPopular
                              ? Colors.amber
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: Responsive.scaleHeight(context, 20)),
              ...features.map((feature) => Padding(
                    padding: EdgeInsets.only(
                        bottom: Responsive.scaleHeight(context, 8)),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: isPopular
                              ? Colors.amber
                              : theme.colorScheme.primary,
                        ),
                        SizedBox(width: Responsive.scaleWidth(context, 8)),
                        Expanded(
                          child: Text(
                            feature,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
              SizedBox(height: Responsive.scaleHeight(context, 16)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.scaleHeight(context, 16),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPopular
                        ? [Colors.amber, Colors.orange]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.primaryContainer,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Subscribe',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isPopular ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditPackages(
      BuildContext context, ThemeData theme, UserData userData) {
    final packages = [
      {'credits': 10, 'bonus': 7, 'productId': '10credit'},
      {'credits': 25, 'bonus': 7, 'productId': '25credit'},
      {'credits': 50, 'bonus': 7, 'productId': '50credit'},
    ];

    return Column(
      children: packages.map((package) {
        return Padding(
          padding: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 12)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.5),
                  theme.colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: InkWell(
              onTap: () async {
                try {
                  await _purchaseService
                      .buyConsumableProduct(package['productId'] as String);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Purchase initiated!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Purchase failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.all(Responsive.scaleWidth(context, 20)),
                child: Row(
                  children: [
                    Container(
                      padding:
                          EdgeInsets.all(Responsive.scaleWidth(context, 16)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primaryContainer,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.stars_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: Responsive.scaleWidth(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${package['credits']} Credits',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(
                                  width: Responsive.scaleWidth(context, 8)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.scaleWidth(context, 8),
                                  vertical: Responsive.scaleHeight(context, 4),
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${package['bonus']} bonus',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.scaleHeight(context, 4)),
                          Text(
                            'One-time purchase • ${(package['credits'] as int) + (package['bonus'] as int)} credits total',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
