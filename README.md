# Datonix setup guide

Files: `supabase-schema.sql`, `index.html`, `n8n-sync-workflow.json`

## 1. Create the Supabase project
1. Sign up at supabase.com and click **New project** (region: Mumbai).
2. Open **Project Settings > API** and copy the **Project URL**, the **anon key** and the **service_role key**.
   The service_role key goes only into n8n, never into the website.

## 2. Run the database file
1. Open `supabase-schema.sql` and replace `YOUR_ADMIN_EMAIL@example.com` with your own email.
2. Paste the whole file into **SQL Editor** and click **Run**.
3. Check **Table Editor**: you should see 13 employees, 1 admin and 13 daily entries.

## 3. Create logins
1. Open **Authentication > Providers > Email**, turn **off** "Allow new users to sign up".
2. Open **Authentication > Users > Add user > Create new user**. Tick **Auto confirm user**.
3. Create your admin login first (same email you put in the SQL), then one login per employee using the email on their record.
4. The database links each login to its employee row automatically. Check that `employees.auth_user_id` is filled.
5. Give each employee their temporary password, or ask them to use **Forgot password** on the site.

## 4. Connect the website
1. Open `index.html` and find the line starting `const SB_URL=`.
2. Paste your Project URL and anon key, then save.
3. Open the file in a browser, sign in as admin and check the totals. Then sign in as one employee and confirm they see only their own data.

## 5. Turn on the n8n sync
1. In n8n choose **Import from file** and select `n8n-sync-workflow.json`.
2. In the **Read Daily Data Entry** node, select your Google Sheets credential.
3. In the **Upsert into Supabase** node, replace `YOUR-PROJECT-REF` in the URL and both `YOUR_SERVICE_ROLE_KEY` values.
4. Click **Execute workflow** once. The sync fails if a sheet row has an Employee ID that is not in the `employees` table, so add that employee first.
5. In the admin dashboard, compare the totals to your Monthly Payout tab, then activate the workflow.

## 6. Deploy
1. Create a free account at vercel.com or netlify.com and upload the `datonix` folder.
2. In the project settings, go to **Domains**, add your domain and copy the DNS records to your domain registrar.
3. HTTPS is enabled automatically once DNS is connected.
4. In Supabase **Authentication > URL Configuration**, set the Site URL to your domain.
5. Replace the placeholder contact and certification text in `index.html`.

## Notes
- Payouts are calculated in the database as hours (capped at 5.30 per day) x hourly rate x (1 - rejection %). This matches your sheet to within a few paise; rounding differences are normal.
- The sheet has no paid/pending column, so payment status starts as Pending and is changed from the admin Payments tab.
- Do not put the service_role key in `index.html`.
