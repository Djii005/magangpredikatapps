# Complete Supabase Setup Guide
## Mobile News & Event App Backend Infrastructure

This guide will walk you through setting up the complete Supabase backend for the mobile news and event application.

---

## Prerequisites

- A Supabase account (sign up at https://supabase.com)
- Access to Supabase Dashboard

---

## Step 1: Create Supabase Project

1. Log in to your Supabase Dashboard
2. Click **New Project**
3. Fill in the project details:
   - **Name**: `news-event-app` (or your preferred name)
   - **Database Password**: Create a strong password (save this!)
   - **Region**: Choose the closest region to your users
   - **Pricing Plan**: Free tier is sufficient for development
4. Click **Create new project**
5. Wait for the project to be provisioned (2-3 minutes)

---

## Step 2: Get Your API Credentials

1. Once the project is ready, go to **Settings** → **API**
2. Copy and save the following credentials:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGc...` (this is your public API key)
   - **service_role key**: `eyJhbGc...` (keep this secret!)

3. Update your Flutter app's `.env` file:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Step 3: Run Database Setup Script

1. In your Supabase Dashboard, go to **SQL Editor**
2. Click **New query**
3. Copy the entire contents of `supabase_setup.sql` file
4. Paste it into the SQL Editor
5. Click **Run** (or press Ctrl/Cmd + Enter)
6. Verify the output shows successful table creation

**What this script does:**
- ✅ Creates `users`, `news`, and `events` tables
- ✅ Sets up indexes for performance
- ✅ Creates triggers for auto-updating timestamps
- ✅ Creates trigger for auto-creating user profiles on signup
- ✅ Enables Row Level Security (RLS)
- ✅ Creates RLS policies for role-based access control
- ✅ Grants necessary permissions

---

## Step 4: Verify Database Setup

Run these verification queries in the SQL Editor:

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'news', 'events');

-- Should return 3 rows: users, news, events
```

```sql
-- Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'news', 'events');

-- All should show rowsecurity = true
```

```sql
-- Check policies
SELECT tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Should show multiple policies for each table
```

---

## Step 5: Set Up Storage Bucket

### 5.1 Create the Bucket

1. Go to **Storage** in the left sidebar
2. Click **New bucket**
3. Configure:
   - **Name**: `images`
   - **Public bucket**: ✅ **Enable** (allows public URL access)
   - **File size limit**: `5242880` (5 MB)
   - **Allowed MIME types**: `image/jpeg,image/png,image/jpg,image/webp`
4. Click **Create bucket**

### 5.2 Configure Storage Policies

1. Go to **Storage** → **Policies**
2. Select the `images` bucket
3. Click **New Policy** for each of the following:

#### Policy 1: Authenticated Upload
- **Policy name**: `Authenticated users can upload images`
- **Policy command**: `INSERT`
- **Target roles**: `authenticated`
- **USING expression**: Leave empty
- **WITH CHECK expression**:
```sql
bucket_id = 'images' AND
(storage.foldername(name))[1] IN ('news', 'events', 'profiles')
```

#### Policy 2: Public Read
- **Policy name**: `Public read access for images`
- **Policy command**: `SELECT`
- **Target roles**: `public`
- **USING expression**:
```sql
bucket_id = 'images'
```

#### Policy 3: Admin Update
- **Policy name**: `Admins can update images`
- **Policy command**: `UPDATE`
- **Target roles**: `authenticated`
- **USING expression**:
```sql
bucket_id = 'images' AND
EXISTS (
  SELECT 1 FROM public.users
  WHERE id = auth.uid() AND role = 'admin'
)
```
- **WITH CHECK expression**: Same as USING

#### Policy 4: Admin Delete
- **Policy name**: `Admins can delete images`
- **Policy command**: `DELETE`
- **Target roles**: `authenticated`
- **USING expression**:
```sql
bucket_id = 'images' AND
EXISTS (
  SELECT 1 FROM public.users
  WHERE id = auth.uid() AND role = 'admin'
)
```

---

## Step 6: Configure Authentication

1. Go to **Authentication** → **Providers**
2. Ensure **Email** provider is enabled (it should be by default)
3. Configure email settings:
   - Go to **Authentication** → **Email Templates**
   - Customize confirmation and password reset emails (optional)
4. Go to **Authentication** → **URL Configuration**
   - Set **Site URL**: Your app's URL (for development, use `http://localhost`)
   - Add **Redirect URLs**: Add your app's deep link URLs

---

## Step 7: Create Admin User

You have two options to create an admin user:

### Option A: Sign Up Then Promote (Recommended)

1. **First, sign up a user through your Flutter app** (once it's running)
   - Or use the Supabase Dashboard: **Authentication** → **Users** → **Add user**
   - Email: `admin@example.com` (use your real email)
   - Password: Create a strong password
   - Auto Confirm User: ✅ Enable

2. **Then promote to admin** via SQL Editor:
```sql
-- Replace with your actual admin email
UPDATE public.users
SET role = 'admin'
WHERE email = 'admin@example.com';

-- Verify the update
SELECT id, email, name, role FROM public.users WHERE role = 'admin';
```

### Option B: Manual Creation (Advanced)

If you need to create an admin user directly:

```sql
-- First, create the auth user (replace with your details)
-- Note: This requires service_role access
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'admin@example.com',
  crypt('your-password-here', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"name":"Admin User"}',
  FALSE,
  ''
);

-- Then the trigger will automatically create the user profile
-- Update it to admin:
UPDATE public.users
SET role = 'admin'
WHERE email = 'admin@example.com';
```

---

## Step 8: Test Your Setup

### Test 1: Verify Tables
```sql
SELECT COUNT(*) FROM public.users;
SELECT COUNT(*) FROM public.news;
SELECT COUNT(*) FROM public.events;
```

### Test 2: Verify Admin User
```sql
SELECT id, email, name, role, created_at 
FROM public.users 
WHERE role = 'admin';
```

### Test 3: Test RLS Policies

Try inserting test data (should fail for non-admin users):
```sql
-- This should work if you're using service_role
-- But will fail for regular authenticated users
INSERT INTO public.news (title, content, summary, author_id)
VALUES (
  'Test News',
  'This is test content',
  'Test summary',
  (SELECT id FROM public.users WHERE role = 'admin' LIMIT 1)
);

-- Verify
SELECT * FROM public.news;

-- Clean up test data
DELETE FROM public.news WHERE title = 'Test News';
```

---

## Step 9: Update Flutter App Configuration

1. Create or update `.env` file in your Flutter project root:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

2. Make sure `.env` is in your `.gitignore`:

```gitignore
.env
*.env
```

3. Create `.env.example` as a template:

```env
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

---

## Step 10: Verify Complete Setup

Run this comprehensive verification query:

```sql
-- Comprehensive Setup Verification
SELECT 
  'Tables Created' as check_type,
  COUNT(*) as count
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('users', 'news', 'events')

UNION ALL

SELECT 
  'RLS Enabled' as check_type,
  COUNT(*) as count
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'news', 'events')
AND rowsecurity = true

UNION ALL

SELECT 
  'Policies Created' as check_type,
  COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public'

UNION ALL

SELECT 
  'Admin Users' as check_type,
  COUNT(*) as count
FROM public.users 
WHERE role = 'admin'

UNION ALL

SELECT 
  'Storage Buckets' as check_type,
  COUNT(*) as count
FROM storage.buckets 
WHERE name = 'images';
```

**Expected Results:**
- Tables Created: 3
- RLS Enabled: 3
- Policies Created: 12+ (4 for users, 4 for news, 4 for events)
- Admin Users: 1+ (at least one admin)
- Storage Buckets: 1

---

## Troubleshooting

### Issue: "relation does not exist"
**Solution**: Make sure you ran the `supabase_setup.sql` script completely.

### Issue: "permission denied for table"
**Solution**: Check that RLS policies are correctly configured and you're authenticated.

### Issue: "new row violates row-level security policy"
**Solution**: 
- For users table: Make sure the trigger is created
- For news/events: Make sure you're logged in as an admin user

### Issue: Cannot upload images
**Solution**: 
- Verify storage bucket is created and set to public
- Check storage policies are configured
- Ensure user is authenticated

### Issue: Admin user not working
**Solution**: 
- Verify the user exists: `SELECT * FROM public.users WHERE email = 'your-email';`
- Check the role is set to 'admin'
- Try logging out and back in

---

## Security Checklist

- ✅ RLS is enabled on all tables
- ✅ Policies restrict write access to admins only
- ✅ Storage policies prevent unauthorized uploads
- ✅ API keys are stored in `.env` (not committed to git)
- ✅ Service role key is kept secret
- ✅ Admin users are created manually (not through app registration)

---

## Next Steps

1. ✅ Complete this Supabase setup
2. ✅ Update your Flutter app's `.env` file with credentials
3. ✅ Test authentication in your Flutter app
4. ✅ Test creating news/events as admin
5. ✅ Test viewing content as regular user
6. ✅ Proceed to next implementation task

---

## Useful Supabase Dashboard Links

- **SQL Editor**: For running queries and scripts
- **Table Editor**: For viewing and manually editing data
- **Authentication**: For managing users
- **Storage**: For managing images
- **API Docs**: Auto-generated API documentation for your project
- **Logs**: For debugging and monitoring

---

## Support Resources

- Supabase Documentation: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- Flutter Supabase Package: https://pub.dev/packages/supabase_flutter

---

**Setup Complete! 🎉**

Your Supabase backend is now ready for the mobile news and event app.
