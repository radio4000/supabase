### Supabase Auth

Configuration is made in the project's settings on https://app.supabase.io.

1. Set the Site URL and Redirect URLs under Authentication -> URL
2. (optional) set up captcha to avoid spam https://supabase.com/docs/guides/auth/auth-captcha

## Social logins

We enable Google, Facebook and email providers.

### Google

1. Go to https://console.cloud.google.com/auth/clients?project=firebase-radio4000
2. Find the `radio4000-live` project and copy the OAuth 2.0 Client ID + secret.

### Facebook

- Original FB app used on r4@v1: https://developers.facebook.com/apps/277294344391580/dashboard/ (note, it's currently disabled)
