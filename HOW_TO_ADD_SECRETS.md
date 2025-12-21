# How to Add Secrets to Supabase Edge Functions

## Step-by-Step Instructions

### Step 1: Go to Supabase Dashboard
1. Open https://supabase.com/dashboard
2. Select your project (the one with ID: `jlkebdnvjjdwedmbfqou`)

### Step 2: Navigate to Edge Functions
1. In the left sidebar, click **"Edge Functions"**
2. You should see your function: `smooth-endpoint`

### Step 3: Add Secrets
There are two ways to add secrets:

#### Option A: From the Function Page
1. Click on your function name: `smooth-endpoint`
2. Look for a **"Settings"** tab or **"Secrets"** section
3. Click **"Add Secret"** or **"Manage Secrets"**
4. Add:
   - **Name:** `THE_MUSE_API_KEY`
   - **Value:** `e176261d566e51adae621988bd6fcc8538f804c0525037c9684085e08f0131e8`
5. Click **"Save"** or **"Add"**

#### Option B: From Project Settings
1. Go to **Project Settings** (gear icon in left sidebar)
2. Click **"Edge Functions"** in the settings menu
3. Look for **"Secrets"** or **"Environment Variables"**
4. Click **"Add Secret"**
5. Add:
   - **Name:** `THE_MUSE_API_KEY`
   - **Value:** `e176261d566e51adae621988bd6fcc8538f804c0525037c9684085e08f0131e8`
6. Click **"Save"**

### Step 4: Also Add Adzuna Secrets (Optional but Recommended)
While you're there, also add:
- **Name:** `ADZUNA_APP_ID`
- **Value:** `ff850947`

- **Name:** `ADZUNA_APP_KEY`
- **Value:** `114516221e332fe7ddb772224a68e0bb`

## How the Code Uses Secrets

The code automatically checks for environment variables first:

```typescript
const API_KEY = Deno.env.get('THE_MUSE_API_KEY') || 'fallback_key'
```

- If the secret exists → uses the secret
- If not → uses the fallback (hardcoded value)

## After Adding Secrets

1. **Redeploy your function:**
   - Go to your Edge Function
   - Click **"Deploy"** (even if code hasn't changed)
   - This ensures the secrets are loaded

2. **Test it:**
   - The function will now use the secrets
   - Check the logs to verify it's working

## Security Benefits

✅ **Secrets are encrypted** in Supabase  
✅ **Not visible** in code or logs  
✅ **Can be rotated** without code changes  
✅ **Best practice** for production

## Verify Secrets Are Working

After deploying, check the logs. You should see:
- Jobs being fetched from The Muse
- No errors about missing API keys

If you see errors, the secrets might not be set correctly.

