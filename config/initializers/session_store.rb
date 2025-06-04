# Use ActiveRecord as the session store instead of cookies
# This prevents CookieOverflow errors when storing large amounts of data in the session
Rails.application.config.session_store :active_record_store, key: '_sci2_session'