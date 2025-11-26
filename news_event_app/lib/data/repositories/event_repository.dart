import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/event_input.dart';
import '../models/result.dart';
import '../../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';

class EventRepository {
  final SupabaseClient _supabaseClient;
  static const String _tableName = 'events';
  static const String _bucketName = 'images';
  static const String _folderName = 'events';

  EventRepository({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  // Get all events with pagination, ordered by event_date ascending
  Future<Result<List<Event>>> getAllEvents({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      AppLogger.debug('Fetching events: limit=$limit, offset=$offset');
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('event_date', ascending: true)
          .range(offset, offset + limit - 1);

      final eventsList = (response as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Successfully fetched ${eventsList.length} events');
      return Result.success(eventsList);
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception fetching events', e, stackTrace);
      return Result.failure('Failed to fetch events. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error fetching events', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching events', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Get only upcoming events (future events)
  Future<Result<List<Event>>> getUpcomingEvents({
    int limit = 20,
  }) async {
    try {
      AppLogger.debug('Fetching upcoming events: limit=$limit');
      final now = DateTime.now().toIso8601String();
      
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .gte('event_date', now)
          .order('event_date', ascending: true)
          .limit(limit);

      final eventsList = (response as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Successfully fetched ${eventsList.length} upcoming events');
      return Result.success(eventsList);
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception fetching upcoming events', e, stackTrace);
      return Result.failure('Failed to fetch upcoming events. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error fetching upcoming events', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching upcoming events', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Get single event by ID
  Future<Result<Event>> getEventById(String id) async {
    try {
      AppLogger.debug('Fetching event by ID: $id');
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      final event = Event.fromJson(response);
      AppLogger.debug('Successfully fetched event: ${event.title}');
      return Result.success(event);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == 'PGRST116') {
        AppLogger.warning('Event not found: $id');
        return Result.failure('Event not found');
      }
      AppLogger.error('Database exception fetching event by ID', e, stackTrace);
      return Result.failure('Failed to fetch event. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error fetching event by ID', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching event by ID', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Create event with validation
  Future<Result<Event>> createEvent(EventInput input) async {
    try {
      AppLogger.info('Creating event: ${input.title}');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Create event failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Validate event date is not in the past
      final now = DateTime.now();
      if (input.eventDate.isBefore(now)) {
        AppLogger.warning('Create event failed: Event date in the past');
        return Result.failure('Event date cannot be in the past');
      }

      // Upload image if provided
      String? imageUrl;
      if (input.image != null) {
        AppLogger.debug('Uploading image for event');
        final uploadResult = await uploadImage(input.image!);
        if (uploadResult.isFailure) {
          return Result.failure(uploadResult.error!);
        }
        imageUrl = uploadResult.data;
      }

      // Prepare data for insertion
      final data = {
        'title': input.title,
        'description': input.description,
        'event_date': input.eventDate.toIso8601String(),
        'event_time': input.eventTime,
        'location': input.location,
        'image_url': imageUrl,
        'author_id': user.id,
      };

      // Insert event into database
      final response = await _supabaseClient
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      final event = Event.fromJson(response);
      AppLogger.info('Event created successfully: ${event.id}');
      return Result.success(event);
    } on SessionExpiredException {
      rethrow;
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error creating event', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on StorageException catch (e, stackTrace) {
      AppLogger.error('Storage exception creating event', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Create event failed: Insufficient permissions');
        return Result.failure('You do not have permission to create events');
      }
      AppLogger.error('Database exception creating event', e, stackTrace);
      return Result.failure('Failed to create event. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error creating event', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Update event
  Future<Result<Event>> updateEvent(String id, EventInput input) async {
    try {
      AppLogger.info('Updating event: $id');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Update event failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Get existing event to check for old image
      final existingResult = await getEventById(id);
      if (existingResult.isFailure) {
        return Result.failure(existingResult.error!);
      }
      final existingEvent = existingResult.data!;

      // Handle image replacement
      String? imageUrl = existingEvent.imageUrl;
      if (input.image != null) {
        AppLogger.debug('Uploading new image for event');
        // Upload new image
        final uploadResult = await uploadImage(input.image!);
        if (uploadResult.isFailure) {
          return Result.failure(uploadResult.error!);
        }
        imageUrl = uploadResult.data;

        // Delete old image if it exists
        if (existingEvent.imageUrl != null) {
          await _deleteImageFromUrl(existingEvent.imageUrl!);
        }
      }

      // Prepare data for update
      final data = {
        'title': input.title,
        'description': input.description,
        'event_date': input.eventDate.toIso8601String(),
        'event_time': input.eventTime,
        'location': input.location,
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update event in database
      final response = await _supabaseClient
          .from(_tableName)
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final event = Event.fromJson(response);
      AppLogger.info('Event updated successfully: $id');
      return Result.success(event);
    } on SessionExpiredException {
      rethrow;
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error updating event', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on StorageException catch (e, stackTrace) {
      AppLogger.error('Storage exception updating event', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Update event failed: Insufficient permissions');
        return Result.failure('You do not have permission to update events');
      }
      if (e.code == 'PGRST116') {
        AppLogger.warning('Update event failed: Event not found');
        return Result.failure('Event not found');
      }
      AppLogger.error('Database exception updating event', e, stackTrace);
      return Result.failure('Failed to update event. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error updating event', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Delete event
  Future<Result<void>> deleteEvent(String id) async {
    try {
      AppLogger.info('Deleting event: $id');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Delete event failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Get existing event to delete associated image
      final existingResult = await getEventById(id);
      if (existingResult.isSuccess && existingResult.data!.imageUrl != null) {
        await _deleteImageFromUrl(existingResult.data!.imageUrl!);
      }

      // Delete event from database
      await _supabaseClient
          .from(_tableName)
          .delete()
          .eq('id', id);

      AppLogger.info('Event deleted successfully: $id');
      return Result.success(null);
    } on SessionExpiredException {
      rethrow;
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error deleting event', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Delete event failed: Insufficient permissions');
        return Result.failure('You do not have permission to delete events');
      }
      AppLogger.error('Database exception deleting event', e, stackTrace);
      return Result.failure('Failed to delete event. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error deleting event', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Upload image to Supabase storage
  Future<Result<String>> uploadImage(File image) async {
    try {
      AppLogger.debug('Uploading image: ${image.path}');
      
      // Validate file exists
      if (!await image.exists()) {
        AppLogger.warning('Upload failed: Image file does not exist');
        return Result.failure('Image file does not exist');
      }

      // Validate file size (max 5MB)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        AppLogger.warning('Upload failed: Image size exceeds limit (${fileSize / 1024 / 1024} MB)');
        return Result.failure('Image size exceeds 5MB limit');
      }

      // Validate file type
      final extension = image.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        AppLogger.warning('Upload failed: Invalid image format ($extension)');
        return Result.failure('Invalid image format. Only JPG, PNG, and WebP are allowed');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = _supabaseClient.auth.currentUser?.id ?? 'anonymous';
      final fileName = '$userId-$timestamp.$extension';
      final filePath = '$_folderName/$fileName';

      // Upload to Supabase storage
      await _supabaseClient.storage
          .from(_bucketName)
          .upload(filePath, image);

      // Get public URL
      final imageUrl = _supabaseClient.storage
          .from(_bucketName)
          .getPublicUrl(filePath);

      AppLogger.info('Image uploaded successfully: $filePath');
      return Result.success(imageUrl);
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error uploading image', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on StorageException catch (e, stackTrace) {
      if (e.message.contains('row-level security')) {
        AppLogger.warning('Upload failed: Insufficient permissions');
        return Result.failure('You do not have permission to upload images');
      }
      AppLogger.error('Storage exception uploading image', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error uploading image', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    }
  }

  // Helper method to delete image from storage using URL
  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
      AppLogger.debug('Deleting image from storage: $imageUrl');
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name and file path in the URL
      final bucketIndex = pathSegments.indexOf('object');
      if (bucketIndex != -1 && bucketIndex + 2 < pathSegments.length) {
        final filePath = pathSegments.sublist(bucketIndex + 2).join('/');
        
        // Delete from storage
        await _supabaseClient.storage
            .from(_bucketName)
            .remove([filePath]);
        
        AppLogger.debug('Image deleted successfully from storage');
      }
    } catch (e, stackTrace) {
      // Log error but don't throw - deletion failure shouldn't block the main operation
      AppLogger.warning('Failed to delete old image from storage', e, stackTrace);
    }
  }
}
