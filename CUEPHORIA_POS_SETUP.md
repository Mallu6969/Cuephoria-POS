# Cuephoria POS - Supabase Setup Guide

## Step 1: Create New Supabase Project

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Click **"New Project"**
3. Fill in the details:
   - **Name**: `Cuephoria POS` (or your preferred name)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Select your plan (Free tier works for development)

4. Wait for the project to be created (takes 1-2 minutes)

## Step 2: Get Your New Supabase Credentials

Once your project is created:

1. Go to **Settings** → **API** in your Supabase dashboard
2. Copy the following values:

   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`
   - **service_role key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (⚠️ Keep this secret!)

## Step 3: Run the Migration

### Option A: Using Supabase Dashboard (Recommended)

1. Go to your new Supabase project dashboard
2. Navigate to **SQL Editor**
3. Click **"New Query"**
4. Copy the entire contents of `supabase/migrations/20250131000012_complete_cuephoria_pos_migration.sql`
5. Paste it into the SQL Editor
6. Click **"Run"** (or press `Ctrl+Enter`)
7. Wait for the migration to complete (should take 10-30 seconds)

### Option B: Using Supabase CLI

```bash
# Install Supabase CLI if you haven't
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project (you'll need your project reference ID)
supabase link --project-ref YOUR_PROJECT_REF

# Run the migration
supabase db push
```

## Step 4: Update Environment Variables

Update your environment variables with the **NEW** Supabase credentials:

### For Local Development (.env file)

Create or update `.env` file in your project root:

```env
# NEW CUEPHORIA POS SUPABASE CREDENTIALS
VITE_SUPABASE_URL=https://YOUR_NEW_PROJECT_ID.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_NEW_ANON_KEY
SUPABASE_ANON_KEY=YOUR_NEW_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_NEW_SERVICE_ROLE_KEY
```

### For Vercel Deployment

1. Go to your Vercel project dashboard
2. Navigate to **Settings** → **Environment Variables**
3. Update or add these variables:
   - `VITE_SUPABASE_URL` = Your new Supabase URL
   - `VITE_SUPABASE_PUBLISHABLE_KEY` = Your new anon key
   - `SUPABASE_ANON_KEY` = Your new anon key (same as above)
   - `SUPABASE_SERVICE_ROLE_KEY` = Your new service_role key

4. **Redeploy** your application after updating variables

## Step 5: Verify the Setup

1. **Check Tables**: Go to Supabase Dashboard → **Table Editor**
   - You should see all tables: `admin_users`, `stations`, `products`, `customers`, `bookings`, etc.

2. **Check Functions**: Go to **Database** → **Functions**
   - You should see: `get_available_slots`, `check_booking_overlap`, etc.

3. **Test Admin Login**:
   - Username: `Cuephoria_admin`
   - Password: `Cuephoria@123`
   - ⚠️ **Change this password immediately after first login!**

## Step 6: Update Your Application

Make sure your application code is pointing to the new environment variables:

The code in `src/integrations/supabase/client.ts` should automatically pick up:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

These are already configured correctly in your codebase!

## Troubleshooting

### Migration Fails
- Check if you're running it on the **NEW** project (not the old one)
- Make sure you have the correct permissions
- Check the SQL Editor for error messages

### Environment Variables Not Working
- Make sure `.env` file is in the project root
- Restart your dev server after updating `.env`
- For Vercel: Make sure you redeployed after updating env vars

### Can't Connect to Supabase
- Verify the URL format: `https://xxxxx.supabase.co` (no trailing slash)
- Check that the keys are correct (no extra spaces)
- Ensure your project is active in Supabase dashboard

## Important Notes

1. **Old Project**: Your old project (`hxjomxplhbrxtqibgrxw.supabase.co`) will remain unchanged
2. **Data Migration**: This migration creates **empty tables**. If you need to migrate data from the old project, you'll need to export/import separately
3. **Storage**: Storage buckets need to be created separately if you're using file uploads
4. **Auth**: If you're using Supabase Auth, you'll need to configure it separately

## Next Steps

1. ✅ Create new Supabase project
2. ✅ Run the migration
3. ✅ Update environment variables
4. ✅ Test the application
5. ⚠️ Change default admin password
6. 📝 Configure Razorpay credentials (if needed)
7. 📝 Set up storage buckets (if needed)
8. 📝 Configure email templates (if needed)

---

**Need Help?** Check the Supabase documentation or review the migration file comments for more details.


