threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

if ENV["RAILS_ENV"] == "production"
  # KHÔNG suy đường dẫn từ `__FILE__`: nó nằm trong thư mục release đã giải
  # symlink. Deploy dùng hot restart (USR2) nên Puma tự re-exec, mà nếu nó gắn
  # với đường dẫn release CŨ thì sau deploy nó nạp lại chính code cũ — deploy
  # báo thành công nhưng không có gì đổi. `directory` trỏ vào symlink `current`
  # để mỗi lần re-exec là chdir sang release mới.
  app_root = ENV.fetch("APP_ROOT", "/var/www/boidat")
  shared   = "#{app_root}/shared"

  directory "#{app_root}/current"
  bind       "unix://#{shared}/tmp/sockets/puma.sock"
  pidfile    "#{shared}/tmp/pids/puma.pid"
  state_path "#{shared}/tmp/pids/puma.state"
  stdout_redirect "#{shared}/log/puma.log", "#{shared}/log/puma.log", true

  workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

  # CỐ Ý không dùng `preload_app!`. Puma chỉ áp dụng `prune_bundler` khi
  # `clustered? && !preload_app` (puma-6.6.1 lib/puma/launcher.rb:368), nên bật
  # preload thì prune_bundler bị bỏ qua ÂM THẦM và hot restart trong chế độ
  # cluster sẽ nạp lại bundle của release cũ. Bỏ preload để cấu hình này đúng
  # với cả WEB_CONCURRENCY=0 lẫn >1; đổi lại, chạy nhiều worker sẽ tốn thêm RAM
  # vì không còn chia sẻ copy-on-write.
  prune_bundler
else
  port ENV.fetch("PORT", 3011)
  plugin :tmp_restart
end

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
