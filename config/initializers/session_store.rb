Rails.application.config.session_store :cookie_store,
  key: "_removlo_session",
  secure: false,
  same_site: :lax