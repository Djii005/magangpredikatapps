import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/event_input.dart';
import '../models/result.dart';

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
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('event_date', ascending: true)
          .range(offset, offset + limit - 1);

      final eventsList = (response as List)
          .map((json) => Event.fromJson(json as Map<String, dynamic>))
          .toList();

      return Result.success(eventsList);
    } on PostgrestException catch (e) {
      return Result.failure('Failed to fetch events: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Get only upcoming events (future events)
  Future<Result<List<Event>>> getUpcomingEvents({
    int limit = 20,
  }) async {
    try {
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

      return Result.success(eventsList);
    } on PostgrestException catch (e) {
      return Result.failure('Failed to fetch upcoming events: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Get single event by ID
  Future<Result<Event>> getEventById(String id) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      final event = Event.fromJson(response);
      return Result.success(event);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Result.failure('Event not found');
      }
      return Result.failure('Failed to fetch event: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Create event with validation
  Future<Result<Event>> createEvent(EventInput input) async {
    try {
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        return Result.failure('User not authenticated');
      }

      // Validate event date is not in the past
      final now = DateTime.now();
      if (input.eventDate.isBefore(now)) {
        return Result.failure('Event date cannot be in the past');
      }

      // Upload image if provided
      String? imageUrl;
      if (input.image != null) {
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
      return Result.success(event);
    } on PostgrestException catch (e) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        return Result.failure('Insufficient permissions to create event');
      }
      return Result.failure('Failed to create event: ${e.message}');
    } on StorageException catch (e) {
      return Result.failure('Failed to upload image: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Update event
  Future<Result<Event>> updateEvent(String id, EventInput input) async {
    try {
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        return Result.failure('User not authenticated');
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
      return Result.success(event);
    } on PostgrestException catch (e) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        return Result.failure('Insufficient permissions to update event');
      }
      if (e.code == 'PGRST116') {
        return Result.failure('Event not found');
      }
      return Result.failure('Failed to update event: ${e.message}');
    } on StorageException catch (e) {
      return Result.failure('Failed to upload image: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Delete event
  Future<Result<void>> deleteEvent(String id) async {
    try {
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        return Result.failure('User not authenticated');
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

      return Result.success(null);
    } on PostgrestException catch (e) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        return Result.failure('Insufficient permissions to delete event');
      }
      return Result.failure('Failed to delete event: ${e.message}');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  // Upload image to Supabase storage
  Future<Result<String>> uploadImage(File image) async {
    try {
      // Validate file exists
      if (!await image.exists()) {
        return Result.failure('Image file does not exist');
      }

      // Validate file size (max 5MB)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        return Result.failure('Image size exceeds 5MB limit');
      }

      // Validate file type
      final extension = image.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
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

      return Result.success(imageUrl);
    } on StorageException catch (e) {
      if (e.message.contains('row-level security')) {
        return Result.failure('Insufficient permissions to upload image');
      }
      return Result.failure('Failed to upload image: ${e.message}');
    } catch (e) {
      return Result.failure('Failed to upload image: $e');
    }
  }

  // Helper method to delete image from storage using URL
  Future<void> _deleteImageFromUrl(String imageUrl) async {
    try {
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
      }
    } catch (e) {
      // Log error but don't throw - deletion failure shouldn't block the main operation
      // In production, use a proper logging framework
      // ignore: avoid_print
      print('Warning: Failed to delete old image: $e');
    }
  }
}
