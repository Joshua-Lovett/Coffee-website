# Coffee menu and ordering site

A single-page site: customers browse the menu, add drinks to an order, and place it
(pay at pickup) and tell us when they'll arrive. The owner signs in on the same page to edit the menu,
see orders, and flip the shop Open or Closed. Each new order sends a push notification to the owner's phone.

- **Hosting:** Netlify (auto-deploys from this repo, no build step)
- **Menu, orders, owner login:** Supabase (free tier)
- **Phone alerts:** ntfy.sh (free app, no account)

## Files
- `index.html` the whole site (change `SHOP_NAME` and `TAGLINE` near the top of the script)
- `supabase-setup.sql` database tables, security rules, and the alert trigger
- `qr.html` printable QR sign for the site address

## One-time setup
1. **Database:** in Supabase > SQL Editor, run `supabase-setup.sql` after replacing
   `OWNER_EMAIL_HERE` and `NTFY_TOPIC_HERE`. Keep the real values out of this public repo.
2. **Owner login:** Supabase > Authentication > Users > Invite user (owner email).
   Under Authentication > URL Configuration, set Site URL to the live site address.
   The owner clicks the emailed link and picks their own password.
   Under Sign In / Providers, turn off "Allow new users to sign up".
3. **Phone alerts:** install the ntfy app, tap +, and subscribe to the topic name from step 1.
4. **Hosting:** in Netlify, import this repo (no build command, publish directory `/`).

## Day to day
Owner: open the site, tap "Owner login" at the bottom. Use "I'm open" / "I'm closed" at the top
(while closed, customers can see the menu but can't order), then the Orders and Edit menu tabs.
