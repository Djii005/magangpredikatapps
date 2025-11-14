# Supabase Storage Setup Guide

## Storage Bucket Configuration

### Step 1: Create Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **New bucket**
4. Configure the bucket:
   - **Name**: `images`
   - **Public bucket**: ✅ Enable (so images can be accessed via public URLs)
   - **File size limit**: 5 MB (recommended)
   - **Allowed MIME types**: `image/jpeg, image/png, image/jpg, image/webp`

### Step 2: Configure Storage Policies

After creating the bucket, you need to set up Row Level Security policies for the storage bucket.

Go to **Storage** → **Policies** → **images bucket** and create the following policies:

#### Policy 1: Allow Authenticated Users to Upload Images

```sql
-- Policy Name: "Authenticated users can upload images"
-- Operation: INSERT
-- Target roles: authenticated

CREATE POLICY "Authenticated users can upload images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images' AND
  (storage.foldername(name))[1] IN ('news', 'events', 'profiles')
);
```

#### Policy 2: Allow Public Read Access to Images

```sql
-- Policy Name: "Public read access for images"
-- Operation: SELECT
-- Target roles: public, authenticated

CREATE POLICY "Public read access for images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'images');
```

#### Policy 3: Allow Admins to Update Images

```sql
-- Policy Name: "Admins can update images"
-- Operation: UPDATE
-- Target roles: authenticated

CREATE POLICY "Admins can update images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images' AND
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  bucket_id = 'images' AND
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

#### Policy 4: Allow Admins to Delete Images

```sql
-- Policy Name: "Admins can delete images"
-- Operation: DELETE
-- Target roles: authenticated

CREATE POLICY "Admins can delete images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images' AND
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  )
);
```

### Alternative: Using Supabase Dashboard UI

If you prefer using the UI instead of SQL:

1. Go to **Storage** → **Policies** → **images bucket**
2. Click **New Policy**
3. For each policy above:
   - Select the operation type (INSERT, SELECT, UPDATE, DELETE)
   - Choose target roles
   - Add the policy definition
   - Click **Review** and **Save**

## Folder Structure

The storage bucket will use the following folder structure:

```
images/
├── news/
│   ├── {uuid}-{timestamp}.jpg
│   └── {uuid}-{timestamp}.png
├── events/
│   ├── {uuid}-{timestamp}.jpg
│   └── {uuid}-{timestamp}.png
└── profiles/
    ├── {uuid}-{timestamp}.jpg
    └── {uuid}-{timestamp}.png
```

## Image Upload Best Practices

1. **File Naming**: Use UUID + timestamp to prevent collisions
   - Example: `550e8400-e29b-41d4-a716-446655440000-1699876543.jpg`

2. **File Size**: Compress images before upload (max 5MB)

3. **Supported Formats**: JPEG, PNG, WebP

4. **Image Optimization**: 
   - Resize large images to max 1920px width
   - Compress quality to 80-85%
   - Use WebP format when possible for better compression

## Getting Image URLs

After uploading an image, you can get the public URL:

```dart
final String imageUrl = supabase
  .storage
  .from('images')
  .getPublicUrl('news/filename.jpg');
```

## Testing Storage Setup

You can test the storage setup by:

1. Creating a test user
2. Authenticating as that user
3. Attempting to upload an image via the Supabase client
4. Verifying the image is accessible via public URL

## Troubleshooting

### Issue: "new row violates row-level security policy"

**Solution**: Make sure:
- The user is authenticated
- The bucket policies are correctly configured
- The bucket is set to public if you want public read access

### Issue: "Failed to upload image"

**Solution**: Check:
- File size is under the limit (5MB)
- File type is allowed (JPEG, PNG, WebP)
- User has proper authentication token
- Storage policies allow INSERT for authenticated users

### Issue: "Cannot access image URL"

**Solution**: Verify:
- Bucket is set to public
- SELECT policy allows public access
- Image path is correct

## Security Notes

1. **Public Bucket**: Images are publicly accessible via URL, but only authenticated users can upload
2. **Admin Control**: Only admins can update or delete images
3. **Folder Structure**: Enforced via policy to organize images by type
4. **File Validation**: Client-side validation should check file type and size before upload

## Next Steps

After completing storage setup:

1. ✅ Verify all policies are active
2. ✅ Test image upload with a test user
3. ✅ Test public image access
4. ✅ Update Flutter app with storage configuration
5. ✅ Implement image upload functionality in the app
