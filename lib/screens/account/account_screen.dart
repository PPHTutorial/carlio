import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/user_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/app_rating_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';
import '../bookmarks/bookmarked_cars_screen.dart';
import '../saved_comparisons/saved_comparisons_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = AuthService();

    // Check if user is logged in
    if (authService.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
        ),
        body: Center(
          child: Padding(
            padding: Responsive.padding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle_rounded,
                  size: 80,
                  color: theme.colorScheme.primaryContainer,
                ),
                SizedBox(height: Responsive.scaleHeight(context, 24)),
                Text(
                  'Sign in to access your account',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Responsive.scaleHeight(context, 32)),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
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
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: StreamBuilder<UserData?>(
        stream: UserService.instance.currentUserData,
        builder: (context, snapshot) {
          final userData = snapshot.data;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: Responsive.padding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Header
                      _buildProfileHeader(context, theme, userData),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),

                      // Account Info Section
                      _buildSectionTitle(context, theme, 'Account'),
                      SizedBox(height: Responsive.scaleHeight(context, 12)),
                      _buildInfoCard(
                        context,
                        theme,
                        icon: Icons.email_rounded,
                        title: 'Email',
                        value:
                            authService.currentUser?.email ?? 'Not available',
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      _buildInfoCard(
                        context,
                        theme,
                        icon: Icons.person_rounded,
                        title: 'Name',
                        value:
                            authService.currentUser?.displayName ?? 'Not set',
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      if (userData != null)
                        _buildInfoCard(
                          context,
                          theme,
                          icon: Icons.stars_rounded,
                          title: 'Credits',
                          value: userData.credits.toStringAsFixed(2),
                          valueColor: theme.colorScheme.primary,
                        ),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),

                      // Premium Section
                      if (userData != null && !userData.hasValidSubscription)
                        _buildPremiumSection(context, theme),

                      // My Collections Section
                      _buildSectionTitle(context, theme, 'My Collections'),
                      SizedBox(height: Responsive.scaleHeight(context, 12)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.bookmark_rounded,
                        title: 'Bookmarked Cars',
                        subtitle: 'View your saved cars',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const BookmarkedCarsScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.compare_arrows_rounded,
                        title: 'Saved Comparisons',
                        subtitle: 'View your saved comparisons',
                        onTap: () {
                          AdService.instance.showAppOpenAd();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SavedComparisonsScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),

                      // Settings Section
                      _buildSectionTitle(context, theme, 'Settings'),
                      SizedBox(height: Responsive.scaleHeight(context, 12)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.diamond_rounded,
                        title: 'Premium Plans',
                        subtitle: 'Upgrade to Pro',
                        onTap: () {
                          AdService.instance.showAppOpenAd();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PremiumScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.share_rounded,
                        title: 'Share App',
                        subtitle: 'Tell your friends about us',
                        onTap: () async {
                          await ShareService().shareApp();
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.star_rounded,
                        title: 'Rate App',
                        subtitle: 'Help us improve',
                        onTap: () async {
                          final ratingService = AppRatingService();
                          final shown = await ratingService.requestRating();
                          if (!shown && context.mounted) {
                            // Fallback: open app store
                            await ShareService().openAppStoreForRating();
                          }
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),

                      // Account Actions
                      _buildSectionTitle(context, theme, 'Account'),
                      SizedBox(height: Responsive.scaleHeight(context, 12)),
                      _buildMenuItem(
                        context,
                        theme,
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        subtitle: 'Sign out of your account',
                        isDestructive: true,
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                  'Are you sure you want to sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            await authService.signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 32)),
                    ],
                  ),
                ),
              ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, ThemeData theme, UserData? userData) {
    final authService = AuthService();
    final isPro = userData?.hasValidSubscription ?? false;

    return Container(
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: Responsive.scaleWidth(context, 80),
            height: Responsive.scaleWidth(context, 80),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: isPro ? Colors.amber : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              isPro ? Icons.verified_rounded : Icons.account_circle_rounded,
              size: Responsive.scaleWidth(context, 50),
              color: isPro ? Colors.amber : theme.colorScheme.primary,
            ),
          ),
          SizedBox(width: Responsive.scaleWidth(context, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        authService.currentUser?.displayName ?? 'User',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPro)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.scaleWidth(context, 8),
                          vertical: Responsive.scaleHeight(context, 4),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: Responsive.scaleWidth(context, 4)),
                            Text(
                              'PRO',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: Responsive.scaleHeight(context, 4)),
                Text(
                  authService.currentUser?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (userData != null) ...[
                  SizedBox(height: Responsive.scaleHeight(context, 12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleWidth(context, 16),
                      vertical: Responsive.scaleHeight(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: Responsive.scaleWidth(context, 8)),
                        Text(
                          '${userData.credits.toStringAsFixed(1)} Credits',
                          style: theme.textTheme.titleMedium?.copyWith(
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
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: Responsive.scaleWidth(context, 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: Responsive.scaleHeight(context, 4)),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSection(BuildContext context, ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 24)),
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.diamond_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: Responsive.scaleWidth(context, 12)),
              Expanded(
                child: Text(
                  'Upgrade to Pro',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.scaleHeight(context, 12)),
          Text(
            'Unlock premium features, remove ads, and get unlimited access!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: Responsive.scaleHeight(context, 16)),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('View Plans'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.scaleWidth(context, 24),
                vertical: Responsive.scaleHeight(context, 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
              decoration: BoxDecoration(
                color: (isDestructive
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer)
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                size: 24,
              ),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: Responsive.scaleHeight(context, 4)),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
