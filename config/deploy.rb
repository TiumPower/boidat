lock "~> 3.18"

set :application, "boidat"
# GitHub, kéo về qua agent forwarding (`forward_agent: true` trong
# config/deploy/production.rb) — giống loyalty/estate/aura/xstudio.
# Đẩy code: `git push origin main` rồi `cap production deploy`.
# Repo bare cũ trên server vẫn còn ở /home/deploy/repos/boidat.git; nếu GitHub
# không với tới được thì chạy `REPO_URL=/home/deploy/repos/boidat.git cap production deploy`
# (nhớ `git push production main` trước, nó KHÔNG tự đồng bộ với GitHub).
set :repo_url,    ENV.fetch("REPO_URL", "git@github.com:TiumPower/boidat.git")

set :deploy_to,   "/var/www/boidat"
set :branch,      ENV.fetch("BRANCH", "main")

# rbenv
set :rbenv_type,   :user
set :rbenv_ruby,   File.read(".ruby-version").strip.sub(/^ruby-/, "")
set :rbenv_prefix, "RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=#{fetch(:rbenv_ruby)} $HOME/.rbenv/bin/rbenv exec"
set :rbenv_path,   "$HOME/.rbenv"

# Shared files/dirs persisted across deploys
set :linked_files, %w[.env]
set :linked_dirs, %w[
  log
  tmp/pids
  tmp/cache
  tmp/sockets
  storage
  public/assets
]

set :keep_releases, 5
set :assets_roles, [:web]

# Puma
set :puma_threads,        [2, 4]
set :puma_workers,        2
set :puma_bind,           "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,          "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,            "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log,     "#{release_path}/log/puma.access.log"
set :puma_error_log,      "#{release_path}/log/puma.error.log"
set :puma_preload_app,    true
set :puma_init_active_record, true

# Sidekiq (systemd)
set :sidekiq_config, "#{current_path}/config/sidekiq.yml"

namespace :deploy do
  desc "Seed database (run manually: cap production deploy:seed)"
  task :seed do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "db:seed"
        end
      end
    end
  end

  after :publishing, :restart

  after :finishing, :restart_sidekiq do
    on roles(:app) do
      execute :sudo, "systemctl restart sidekiq-boidat"
    end
  end

  # Keep the nightly backup script in shared/ rather than in the release: a bad
  # deploy (or a rolled-back release) must never be able to stop backups. The
  # source of truth stays in the repo, copied out on every deploy.
  desc "Chuyển tệp còn trên đĩa lên kho hiện tại (cap production deploy:storage_migrate)"
  task :storage_migrate do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "storage:migrate"
        end
      end
    end
  end

  desc "Đối chiếu mọi blob đọc được và đúng checksum (cap production deploy:storage_verify)"
  task :storage_verify do
    on roles(:app) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, "storage:verify"
        end
      end
    end
  end

  desc "Install the nightly backup script and its cron entry"
  task :install_backup do
    on roles(:db) do
      dest = "#{shared_path}/bin/boidat_backup.sh"
      execute :mkdir, "-p", "#{shared_path}/bin"
      upload! "bin/boidat_backup.sh", dest
      execute :chmod, "+x", dest
      line = "15 3 * * * #{dest} >> #{shared_path}/log/backup.log 2>&1"
      # Idempotent: drop any previous boidat_backup line, then append ours.
      execute %(crontab -l 2>/dev/null | grep -v 'boidat_backup.sh' > /tmp/boidat_cron || true)
      execute %(echo "#{line}" >> /tmp/boidat_cron && crontab /tmp/boidat_cron && rm -f /tmp/boidat_cron)
    end
  end
  after :finishing, :install_backup
end
