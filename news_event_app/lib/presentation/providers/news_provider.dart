import 'package:flutter/foundation.dart';
import '../../data/models/news_model.dart';
import '../../data/models/news_input.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/exceptions/app_exceptions.dart';
import '../../utils/app_logger.dart';

class NewsProvider extends ChangeNotifier {
  final NewsRepository _newsRepository;

  // State fields
  List<News> _newsList = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  NewsProvider({required NewsRepository newsRepository})
      : _newsRepository = newsRepository;

  // Getters
  List<News> get newsList => _newsList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNews => _newsList.isNotEmpty;

  // Check if cache is still valid
  bool get _isCacheValid {
    if (_lastFetchTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < _cacheDuration;
  }

  // Fetch news with caching logic
  Future<void> fetchNews({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid && _newsList.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _newsRepository.getAllNews(
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess && result.data != null) {
        _newsList = result.data!;
        _lastFetchTime = DateTime.now();
        _setLoading(false);
        notifyListeners();
      } else {
        _setError(result.error ?? 'Failed to fetch news');
        _setLoading(false);
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
    }
  }

  // Refresh news (clears cache and fetches fresh data)
  Future<void> refreshNews() async {
    _lastFetchTime = null; // Invalidate cache
    await fetchNews(forceRefresh: true);
  }

  // Create news article
  Future<bool> createNews(NewsInput input) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _newsRepository.createNews(input);

      if (result.isSuccess && result.data != null) {
        // Refresh the news list to include the new article
        await refreshNews();
        return true;
      } else {
        _setError(result.error ?? 'Failed to create news');
        _setLoading(false);
        return false;
      }
    } on SessionExpiredException catch (e) {
      AppLogger.warning('Session expired during create news');
      _setError(e.message);
      _setLoading(false);
      rethrow; // Re-throw to be handled by UI
    } catch (e, stackTrace) {
      AppLogger.error('Error creating news', e, stackTrace);
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // Update news article
  Future<bool> updateNews(String id, NewsInput input) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _newsRepository.updateNews(id, input);

      if (result.isSuccess && result.data != null) {
        // Refresh the news list to reflect the update
        await refreshNews();
        return true;
      } else {
        _setError(result.error ?? 'Failed to update news');
        _setLoading(false);
        return false;
      }
    } on SessionExpiredException catch (e) {
      AppLogger.warning('Session expired during update news');
      _setError(e.message);
      _setLoading(false);
      rethrow; // Re-throw to be handled by UI
    } catch (e, stackTrace) {
      AppLogger.error('Error updating news', e, stackTrace);
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // Delete news article
  Future<bool> deleteNews(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _newsRepository.deleteNews(id);

      if (result.isSuccess) {
        // Refresh the news list to remove the deleted article
        await refreshNews();
        return true;
      } else {
        _setError(result.error ?? 'Failed to delete news');
        _setLoading(false);
        return false;
      }
    } on SessionExpiredException catch (e) {
      AppLogger.warning('Session expired during delete news');
      _setError(e.message);
      _setLoading(false);
      rethrow; // Re-throw to be handled by UI
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting news', e, stackTrace);
      _setError('An unexpected error occurred. Please try again.');
      _setLoading(false);
      return false;
    }
  }

  // Helper methods for state management
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear error message manually (useful for dismissing error messages in UI)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Clear all data (useful for logout)
  void clear() {
    _newsList = [];
    _lastFetchTime = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
