/* King's Clubhouse · site configuration
   Since 9 Nov 2026 the backend is the King's Clubhouse workspace in mapmyshift.com — the website reads its events,
   photo spots, gallery and What's on calendar from API_BASE, and posts its enquiry and sign-up forms there.
   The two SUPABASE lines are the old staff area, kept only as a fallback for the switch-over: if mapmyshift can't be
   reached, a form still lands in Supabase (Settings → "Bring everything across" in mapmyshift sweeps it up).
   Once mapmyshift has been live for a week, blank both SUPABASE lines. Public values only — nothing secret goes here. */
window.KC_CONFIG = {
  API_BASE: "https://mapmyshift.com/api/site/kings-clubhouse",
  SUPABASE_URL: "https://dnjqpcaryfinyicvzkiy.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_R7PpKss6uAnUqsVbYaBJbg_IDNFz8iK"   // "publishable" key — public by design
};
