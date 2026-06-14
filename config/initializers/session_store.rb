Rails.application.config.session_store :cookie_store,
  key: "_removlo_session",
  secure: true,
  same_site: :lax