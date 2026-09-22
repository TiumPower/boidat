require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # Kho lưu trữ tệp: Spaces khi đã cấu hình, ngược lại rơi về đĩa của máy chủ.
  #
  # Cố ý không viết cứng `:spaces`. Thiếu một biến môi trường mà app vẫn trỏ
  # sang S3 thì mọi lần tải ảnh lên đều nổ trên production, và lỗi chỉ lộ ra
  # lúc một phụ huynh đang gửi ảnh khuôn mặt cho con. Chưa đủ khoá thì chạy
  # tiếp trên đĩa, có nhật ký sao lưu hằng đêm đỡ.
  config.active_storage.service =
    if ENV["SPACES_BUCKET"].present? && ENV["SPACES_KEY"].present?
      ENV["SPACES_MIRROR_LOCAL"] == "false" ? :spaces : :spaces_mirrored
    else
      :local
    end

  # Tệp riêng tư đi qua ứng dụng chứ không phát link trần ra bucket — ảnh khuôn
  # mặt trẻ em và chữ ký trên cam kết không được nằm sau một URL đoán được.
  config.active_storage.resolve_model_to_route = :rails_storage_proxy

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "boidat_production"

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Background jobs via Sidekiq
  config.active_job.queue_adapter = :sidekiq

  # Mailer URLs
  config.action_mailer.default_url_options = { host: "boidat.tiumpower.com", protocol: "https" }

  # Email delivery for OTP. Prefer Brevo's HTTP API (works over 443 where SMTP
  # ports are blocked, e.g. DigitalOcean); fall back to SMTP if configured.
  if ENV["BREVO_API_KEY"].present?
    config.action_mailer.delivery_method = :brevo
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
  elsif ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address:              ENV["SMTP_ADDRESS"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      domain:               ENV.fetch("SMTP_DOMAIN", "boidat.tiumpower.com"),
      authentication:       :login,
      enable_starttls_auto: true
    }
  end

  # Host authorization — apex + every shop subdomain (white-label PWA).
  # Host nền tảng có ba nhãn (boidat.tiumpower.com), nên với tld_length mặc định là 1
  # Rails đọc chính nó thành "subdomain boidat" — trùng đúng subdomain của trung
  # tâm BƠI ĐẠT. Hậu quả: apex bị nhận nhầm là trung tâm đó và chuyển thẳng sang
  # boidat.boidat.tiumpower.com, nên trang giới thiệu ở host trần không bao giờ tới
  # được, và nếu có trung tâm thứ hai thì apex vẫn thuộc về trung tâm nào tình
  # cờ trùng tên với host.
  #
  # Suy từ PLATFORM_HOST chứ không viết cứng số 2: dev và test chạy trên
  # example.com hai nhãn, đặt cứng là hỏng toàn bộ test subdomain.
  config.action_dispatch.tld_length = ENV.fetch("PLATFORM_HOST", "boidat.tiumpower.com").count(".")

  config.hosts << "boidat.tiumpower.com"
  config.hosts << /.*\.boidat\.tiumpower\.com/
  # Tên miền cũ (czin.net) — nginx đã 301 sang domain mới, giữ lại cho chắc.
  config.hosts << "boidat.czin.net"
  config.hosts << /.*\.boidat\.czin\.net/
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
