import 'package:flutter/foundation.dart';
import '../../data/models/event_model.dart';
import '../../data/models/event_input.dart';
import '../../data/repositories/event_repository.dart';

class EventProvider extends ChangeNotifier {
  final EventRepository _eventRepository;

  // State fields
  List<Event> _eventsList = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  EventProvider({required EventRepository eventRepository})
      : _eventRepository = eventRepository;

  // Getters
  List<Event> get eventsList => _eventsList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasEvents => _eventsList.isNotEmpty;

  // Check if cache is still valid
  bool get _isCacheValid {
    if (_lastFetchTime == null) return false;
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < _cacheDuration;
  }

  // Fetch events with caching logic
  Future<void> fetchEvents({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && _isCacheValid && _eventsList.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final result = await _eventRepository.getAllEvents(
        limit: limit,
        offset: offset,
      );

      if (result.isSuccess && result.data != null) {
        _eventsList = result.data!;
        _lastFetchTime = DateTime.now();
        _setLoading(false);
        notifyListeners();
      } else {
        _setError(result.error ?? 'Failed to fetch events');
        _setLoading(false);
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
    }
  }

  // Refresh events (clears cache and fetches fresh data)
  Future<void> refreshEvents() async {
    _lastFetchTime = null; // Invalidate cache
    await fetchEvents(forceRefresh: true);
  }

  // Create event
  Future<bool> createEvent(EventInput input) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _eventRepository.createEvent(input);

      if (result.isSuccess && result.data != null) {
        // Refresh the events list to include the new event
        await refreshEvents();
        return true;
      } else {
        _setError(result.error ?? 'Failed to create event');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update event
  Future<bool> updateEvent(String id, EventInput input) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _eventRepository.updateEvent(id, input);

      if (result.isSuccess && result.data != null) {
        // Refresh the events list to reflect the update
        await refreshEvents();
        return true;
      } else {
        _setError(result.error ?? 'Failed to update event');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
      _setLoading(false);
      return false;
    }
  }

  // Delete event
  Future<bool> deleteEvent(String id) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _eventRepository.deleteEvent(id);

      if (result.isSuccess) {
        // Refresh the events list to remove the deleted event
        await refreshEvents();
        return true;
      } else {
        _setError(result.error ?? 'Failed to delete event');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('An unexpected error occurred: $e');
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
    _eventsList = [];
    _lastFetchTime = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
