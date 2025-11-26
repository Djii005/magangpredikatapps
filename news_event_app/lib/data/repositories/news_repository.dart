import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_model.dart';
import '../models/news_input.dart';
import '../models/result.dart';
import '../../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';

class NewsRepository {
  final SupabaseClient _supabaseClient;
  static const String _tableName = 'news';
  static const String _bucketName = 'images';
  static const String _folderName = 'news';

  NewsRepository({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  // Get all news with pagination
  Future<Result<List<News>>> getAllNews({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      AppLogger.debug('Fetching news: limit=$limit, offset=$offset');
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final newsList = (response as List)
          .map((json) => News.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('Successfully fetched ${newsList.length} news articles');
      return Result.success(newsList);
    } on PostgrestException catch (e, stackTrace) {
      AppLogger.error('Database exception fetching news', e, stackTrace);
      return Result.failure('Failed to fetch news. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error fetching news', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching news', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Get single news by ID
  Future<Result<News>> getNewsById(String id) async {
    try {
      AppLogger.debug('Fetching news by ID: $id');
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      final news = News.fromJson(response);
      AppLogger.debug('Successfully fetched news: ${news.title}');
      return Result.success(news);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == 'PGRST116') {
        AppLogger.warning('News article not found: $id');
        return Result.failure('News article not found');
      }
      AppLogger.error('Database exception fetching news by ID', e, stackTrace);
      return Result.failure('Failed to fetch news. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error fetching news by ID', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching news by ID', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Create news article
  Future<Result<News>> createNews(NewsInput input) async {
    try {
      AppLogger.info('Creating news article: ${input.title}');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Create news failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Upload image if provided
      String? imageUrl;
      if (input.image != null) {
        AppLogger.debug('Uploading image for news article');
        final uploadResult = await uploadImage(input.image!);
        if (uploadResult.isFailure) {
          return Result.failure(uploadResult.error!);
        }
        imageUrl = uploadResult.data;
      }

      // Prepare data for insertion
      final data = {
        'title': input.title,
        'content': input.content,
        'summary': input.summary,
        'image_url': imageUrl,
        'author_id': user.id,
      };

      // Insert news into database
      final response = await _supabaseClient
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      final news = News.fromJson(response);
      AppLogger.info('News article created successfully: ${news.id}');
      return Result.success(news);
    } on SessionExpiredException {
      rethrow;
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error creating news', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on StorageException catch (e, stackTrace) {
      AppLogger.error('Storage exception creating news', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Create news failed: Insufficient permissions');
        return Result.failure('You do not have permission to create news articles');
      }
      AppLogger.error('Database exception creating news', e, stackTrace);
      return Result.failure('Failed to create news. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error creating news', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Update news article
  Future<Result<News>> updateNews(String id, NewsInput input) async {
    try {
      AppLogger.info('Updating news article: $id');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Update news failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Get existing news to check for old image
      final existingResult = await getNewsById(id);
      if (existingResult.isFailure) {
        return Result.failure(existingResult.error!);
      }
      final existingNews = existingResult.data!;

      // Handle image replacement
      String? imageUrl = existingNews.imageUrl;
      if (input.image != null) {
        AppLogger.debug('Uploading new image for news article');
        // Upload new image
        final uploadResult = await uploadImage(input.image!);
        if (uploadResult.isFailure) {
          return Result.failure(uploadResult.error!);
        }
        imageUrl = uploadResult.data;

        // Delete old image if it exists
        if (existingNews.imageUrl != null) {
          await _deleteImageFromUrl(existingNews.imageUrl!);
        }
      }

      // Prepare data for update
      final data = {
        'title': input.title,
        'content': input.content,
        'summary': input.summary,
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update news in database
      final response = await _supabaseClient
          .from(_tableName)
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final news = News.fromJson(response);
      AppLogger.info('News article updated successfully: $id');
      return Result.success(news);
    } on SessionExpiredException {
      rethrow;
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error updating news', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } on StorageException catch (e, stackTrace) {
      AppLogger.error('Storage exception updating news', e, stackTrace);
      return Result.failure('Failed to upload image. Please try again.');
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Update news failed: Insufficient permissions');
        return Result.failure('You do not have permission to update news articles');
      }
      if (e.code == 'PGRST116') {
        AppLogger.warning('Update news failed: Article not found');
        return Result.failure('News article not found');
      }
      AppLogger.error('Database exception updating news', e, stackTrace);
      return Result.failure('Failed to update news. Please try again.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error updating news', e, stackTrace);
      return Result.failure('An unexpected error occurred. Please try again.');
    }
  }

  // Delete news article
  Future<Result<void>> deleteNews(String id) async {
    try {
      AppLogger.info('Deleting news article: $id');
      
      // Check if user is authenticated
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        AppLogger.warning('Delete news failed: User not authenticated');
        throw SessionExpiredException();
      }

      // Get existing news to delete associated image
      final existingResult = await getNewsById(id);
      if (existingResult.isSuccess && existingResult.data!.imageUrl != null) {
        await _deleteImageFromUrl(existingResult.data!.imageUrl!);
      }

      // Delete news from database
      await _supabaseClient
          .from(_tableName)
          .delete()
          .eq('id', id);

      AppLogger.info('News article deleted successfully: $id');
      return Result.success(null);
    } on SessionExpiredException {
      rethrow;
    } on PostgrestException catch (e, stackTrace) {
      // Check for authorization errors
      if (e.code == '42501' || e.message.contains('permission denied')) {
        AppLogger.warning('Delete news failed: Insufficient permissions');
        return Result.failure('You do not have permission to delete news articles');
      }
      AppLogger.error('Database exception deleting news', e, stackTrace);
      return Result.failure('Failed to delete news. Please try again.');
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('Network error deleting news', e, stackTrace);
      return Result.failure('No internet connection. Please check your network.');
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error deleting news', e, stackTrace);
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
