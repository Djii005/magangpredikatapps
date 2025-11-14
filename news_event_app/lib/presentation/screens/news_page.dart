import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/news_card.dart';
import 'news_detail_screen.dart';
import 'create_news_screen.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  @override
  void initState() {
    super.initState();
    // Fetch news when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().fetchNews();
    });
  }

  Future<void> _handleRefresh() async {
    final newsProvider = context.read<NewsProvider>();
    await newsProvider.refreshNews();
    
    // Show error message if refresh failed
    if (mounted && newsProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newsProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      newsProvider.clearError();
    }
  }

  void _navigateToCreateNews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateNewsScreen(),
      ),
    );
  }

  void _navigateToNewsDetail(String newsId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(newsId: newsId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final newsProvider = context.watch<NewsProvider>();
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('News'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Builder(
          builder: (context) {
            // Show loading indicator on initial load
            if (newsProvider.isLoading && !newsProvider.hasNews) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Show empty state when no news available
            if (!newsProvider.hasNews && !newsProvider.isLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No news available',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Show news list
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: newsProvider.newsList.length,
              itemBuilder: (context, index) {
                final news = newsProvider.newsList[index];
                return NewsCard(
                  news: news,
                  onTap: () => _navigateToNewsDetail(news.id),
                );
              },
            );
          },
        ),
      ),
      // Floating action button visible only to admins
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _navigateToCreateNews,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
