# Supabase Quick Reference Card

## Essential Credentials

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**Location**: Settings → API in Supabase Dashboard

---

## Quick Setup Commands

### 1. Run Main Setup Script
Copy and paste `supabase_setup.sql` into SQL Editor → Run

### 2. Create Admin User
```sql
-- After user signs up, promote to admin:
UPDATE public.users
SET role = 'admin'
WHERE email = 'your-admin-email@example.com';
```

### 3. Verify Setup
```sql
-- Check tables
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN ('users', 'news', 'events');

-- Check admin users
SELECT email, role FROM public.users WHERE role = 'admin';

-- Check RLS
SELECT tablename, rowsecurity FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN ('users', 'news', 'events');
```

---

## Database Schema

### Users Table
```
id          UUID (PK, FK to auth.users)
email       TEXT (UNIQUE, NOT NULL)
name        TEXT (NOT NULL)
role        TEXT (NOT NULL, DEFAULT 'user') CHECK IN ('user', 'admin')
created_at  TIMESTAMP (DEFAULT NOW())
```

### News Table
```
id          UUID (PK, DEFAULT uuid_generate_v4())
title       TEXT (NOT NULL)
content     TEXT (NOT NULL)
summary     TEXT
image_url   TEXT
author_id   UUID (FK to users.id)
created_at  TIMESTAMP (DEFAULT NOW())
updated_at  TIMESTAMP (DEFAULT NOW())
```

### Events Table
```
id          UUID (PK, DEFAULT uuid_generate_v4())
title       TEXT (NOT NULL)
description TEXT (NOT NULL)
event_date  DATE (NOT NULL)
event_time  TEXT
location    TEXT (NOT NULL)
image_url   TEXT
author_id   UUID (FK to users.id)
created_at  TIMESTAMP (DEFAULT NOW())
updated_at  TIMESTAMP (DEFAULT NOW())
```

---

## Storage Configuration

### Bucket Name
`images`

### Folder Structure
```
images/
├── news/
├── events/
└── profiles/
```

### Storage Policies Required
1. **INSERT**: Authenticated users can upload
2. **SELECT**: Public read access
3. **UPDATE**: Admins only
4. **DELETE**: Admins only

---

## RLS Policies Summary

### Users Table
- ✅ Users can read own profile
- ✅ Users can update own profile (except role)
- ✅ Auto-insert via trigger on signup

### News Table
- ✅ All authenticated users can read
- ✅ Only admins can insert/update/delete

### Events Table
- ✅ All authenticated users can read
- ✅ Only admins can insert/update/delete

---

## Common SQL Queries

### View All Users
```sql
SELECT id, email, name, role, created_at FROM public.users ORDER BY created_at DESC;
```

### View All News
```sql
SELECT id, title, summary, author_id, created_at FROM public.news ORDER BY created_at DESC;
```

### View All Events
```sql
SELECT id, title, event_date, location, author_id FROM public.events ORDER BY event_date ASC;
```

### Make User Admin
```sql
UPDATE public.users SET role = 'admin' WHERE email = 'user@example.com';
```

### Remove Admin Role
```sql
UPDATE public.users SET role = 'user' WHERE email = 'user@example.com';
```

### Delete Test Data
```sql
DELETE FROM public.news WHERE title LIKE '%test%';
DELETE FROM public.events WHERE title LIKE '%test%';
```

### View User's Content
```sql
-- News by specific user
SELECT * FROM public.news WHERE author_id = 'user-uuid-here';

-- Events by specific user
SELECT * FROM public.events WHERE author_id = 'user-uuid-here';
```

---

## Testing Checklist

- [ ] Tables created (users, news, events)
- [ ] RLS enabled on all tables
- [ ] Policies created (12+ total)
- [ ] Storage bucket 'images' created
- [ ] Storage policies configured (4 policies)
- [ ] At least one admin user created
- [ ] Can sign up new user via app
- [ ] Can login as admin
- [ ] Can create news as admin
- [ ] Can create event as admin
- [ ] Regular user cannot see admin buttons
- [ ] Can upload images to storage

---

## Troubleshooting Quick Fixes

### Reset RLS Policies
```sql
-- Drop all policies
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
-- ... (drop all others)

-- Then re-run the policy creation section from supabase_setup.sql
```

### Reset Tables (DANGER: Deletes all data!)
```sql
DROP TABLE IF EXISTS public.events CASCADE;
DROP TABLE IF EXISTS public.news CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Then re-run supabase_setup.sql
```

### Check Policy Effectiveness
```sql
-- See what policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### View Auth Users
```sql
SELECT id, email, created_at, email_confirmed_at 
FROM auth.users 
ORDER BY created_at DESC;
```

---

## Important Notes

⚠️ **Never commit** your `.env` file with real credentials
⚠️ **Keep service_role key secret** - it bypasses RLS
⚠️ **Admin users** must be created manually (not through app signup)
⚠️ **Test RLS policies** before deploying to production
⚠️ **Backup your database** before making schema changes

---

## Support

- 📚 Docs: https://supabase.com/docs
- 💬 Discord: https://discord.supabase.com
- 🐛 Issues: Check Supabase Dashboard → Logs

---

**Quick Start**: Run `supabase_setup.sql` → Create storage bucket → Make admin user → Done! ✅
