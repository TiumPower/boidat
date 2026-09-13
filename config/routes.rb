Rails.application.routes.draw do
  # ---- Devise ------------------------------------------------------------
  # Nhân sự (User) đăng nhập bằng email + mật khẩu do Admin đặt (FR-218);
  # controller riêng để thêm luồng OTP quên mật khẩu và QR đăng nhập nhanh.
  # Phụ huynh (Guardian) KHÔNG dùng Devise — cookie ký + QR hộ gia đình / OTP.
  devise_for :users, path: "login", path_names: { sign_in: "", sign_out: "logout" },
             controllers: { sessions: "users/sessions" }
  devise_for :admin_users,
             path: "admin",
             path_names: { sign_in: "login", sign_out: "logout", password: "password" },
             skip: [:registrations]

  # ---- PayOS webhook (không CSRF) ----------------------------------------
  post "webhooks/payos" => "webhooks/payos#receive", as: :payos_webhook

  # ---- PWA: mỗi cổng một manifest + service worker riêng -----------------
  get "manifest.webmanifest"         => "pwa/manifests#show",         as: :pwa_manifest
  get "teacher/manifest.webmanifest" => "pwa/manifests#teacher",      as: :teacher_pwa_manifest
  get "desk/manifest.webmanifest"    => "pwa/manifests#desk",         as: :desk_pwa_manifest
  get "service-worker.js"            => "pwa/service_workers#show",   as: :pwa_service_worker

  # ---- Đổi ngôn ngữ ------------------------------------------------------
  get "/set_locale/:locale", to: "locales#update", as: :set_locale

  # ---- Super Admin nền tảng : /admin -------------------------------------
  namespace :admin do
    root "dashboard#show"
    resources :workspaces, only: [:index, :new, :create, :show, :update, :destroy] do
      member do
        patch :approve
        patch :suspend
        patch :reactivate
        post  :impersonate
      end
    end
    get "billing",    to: "billing#show"
    resources :plans, only: [:index, :update]
    get   "account", to: "account#edit", as: :account
    patch "account", to: "account#update"
  end

  # ---- Back office của trung tâm : /merchant -----------------------------
  # Hai khu vực dùng chung base controller, sidebar khác nhau theo vai trò:
  #   /merchant/bod — cổng điều hành (S1, BOD / Super Admin của trung tâm)
  #   /merchant/ops — cổng vận hành (S2, Admin / Sale)
  namespace :merchant do
    root "home#show"

    # Chuyển hồ đang làm việc (FR-201) — nhớ giữa các phiên.
    post "switch-pool/:pool_id", to: "home#switch_pool", as: :switch_pool

    # Cổng điều hành — BOD
    namespace :bod do
      root "dashboard#show"
      get  "reports", to: "reports#index", as: :reports
      resources :pools do
        resources :holidays, only: [:create, :destroy]
        member { patch :assign_staff }
      end
      resources :staff, only: [:index, :new, :create, :edit, :update, :destroy] do
        member { patch :reset_password }
      end
      resources :teachers, only: [:index, :show, :new, :create, :edit, :update]
      resources :teacher_levels, path: "levels", except: [:show]
      resources :courses do
        member { post :generate_plan }
      end
      resources :packages, path: "packages" do
        resources :prices, only: [:create, :destroy], controller: "price_list_items"
      end
      resources :promotions, except: [:show]
      get   "settings", to: "settings#edit",   as: :settings
      patch "settings", to: "settings#update"
      get   "appearance", to: "appearance#edit", as: :appearance
      patch "appearance", to: "appearance#update"
      resources :audit_logs, path: "audit", only: [:index]
    end

    # Cổng vận hành — Admin / Sale
    namespace :ops do
      root "schedule#index"                       # bảng master data lịch (FR-202)
      get "schedule/slot", to: "schedule#slot", as: :schedule_slot
      resources :registrations, only: [:new, :create] do
        collection { get :households }
      end
      resources :classes, only: [:show, :edit, :update], controller: "swim_classes"
      resources :lessons, only: [:show, :update] do
        member { patch :attend }
      end
      resources :students, only: [:index, :show, :new, :create, :edit, :update]
      resources :households, only: [:index, :show] do
        member { post :reissue_qr }
      end
      resources :teachers, only: [:index, :show]
      resources :packages, only: [:index]   # sale tra bảng giá khi chốt lịch
      resources :graduations, only: [:index, :update]   # danh sách thi tốt nghiệp (FR-208)
      resources :day_passes, path: "day-passes", only: [:index, :create]  # bán vé lẻ nhanh (FR-214)
      get  "timesheets", to: "timesheets#index", as: :timesheets           # tab chấm công (FR-210)
      post "timesheets/lock", to: "timesheets#lock", as: :lock_timesheets
      resources :audit_logs, path: "audit", only: [:index]
    end

    # Hồ sơ cá nhân của nhân sự (FR-219) — dùng chung cho mọi vai trò.
    get   "account", to: "account#edit",   as: :account
    patch "account", to: "account#update"
    get   "account/qr", to: "account#qr",  as: :account_qr   # QR đăng nhập nhanh PWA

    # Thuê bao nền tảng (trung tâm trả tiền cho chúng ta)
    get  "billing",        to: "subscription#show",   as: :billing
    post "billing/pay",    to: "subscription#create", as: :billing_pay
    get  "billing/return", to: "subscription#return", as: :billing_return

    post "push/subscribe",   to: "push#subscribe",   as: :push_subscribe
    post "push/unsubscribe", to: "push#unsubscribe", as: :push_unsubscribe
  end

  # ---- Quầy điểm danh (S3, PWA lễ tân) : /desk ---------------------------
  namespace :desk do
    root "attendance#index"
    get  "shift",        to: "attendance#index", as: :shift
    post "select-pool/:pool_id", to: "attendance#select_pool", as: :select_pool
    get  "scan",         to: "scans#new",     as: :scan
    post "scan",         to: "scans#create"                     # gửi ảnh khuôn mặt
    post "scan/ticket",  to: "scans#ticket",  as: :scan_ticket   # quét vé lẻ QR một lần
    post "push/subscribe", to: "push#subscribe", as: :push_subscribe
  end

  # Đăng nhập nhanh bằng QR cho nhân sự (quét mã trên hồ sơ web).
  get "/s/:token", to: "quick_logins#show", as: :staff_quick_login

  # ---- Cổng giáo viên (S4, PWA) : /teacher -------------------------------
  # module :coach chứ không phải :teacher — tránh va tên với model Teacher (Zeitwerk).
  scope path: "teacher", module: :coach, as: :teacher do
    root "schedule#index", as: :root
    resources :lessons, only: [:show, :update] do
      resources :feedbacks, only: [:new, :create]
    end
    get  "timesheet", to: "timesheet#index", as: :timesheet
    get  "availability", to: "availability#edit", as: :availability
    patch "availability", to: "availability#update"
    resources :leave_requests, path: "leaves", only: [:index, :new, :create]
    get   "account", to: "account#edit", as: :account
    patch "account", to: "account#update"
    post "push/subscribe",   to: "push#subscribe",   as: :push_subscribe
    post "push/unsubscribe", to: "push#unsubscribe", as: :push_unsubscribe
  end

  # ---- Cổng phụ huynh / học viên (S5, PWA) -------------------------------
  # Chạy trên subdomain của trung tâm ở production, hoặc /w/:slug ở dev.
  # Route helper giữ tiền tố `member_` như khung Estate/Loyalty.
  scope "(/w/:workspace_slug)", module: :customer, as: :member do
    root "home#show", as: :root

    # Đăng nhập: quét QR hộ gia đình, hoặc SĐT + OTP với người lớn tự học (FR-401)
    get    "login",       to: "sessions#new",         as: :login
    post   "login",       to: "sessions#create"
    get    "verify",      to: "sessions#verify_form", as: :verify
    post   "verify",      to: "sessions#verify",      as: :verify_submit
    delete "logout",      to: "sessions#destroy",     as: :logout
    get    "q/:qr_token", to: "sessions#qr",          as: :qr_login

    # Ảnh khuôn mặt + đồng ý dữ liệu sinh trắc học (FR-402)
    get    "faces",              to: "faces#index",   as: :faces
    post   "faces/:student_id",  to: "faces#create",  as: :create_face
    delete "faces/:student_id",  to: "faces#destroy", as: :destroy_face

    # Học viên: tiến độ + nhận xét của giáo viên (FR-406)
    get "students/:id", to: "students#show", as: :student

    get  "notifications",          to: "notifications#index",   as: :notifications
    post "notifications/read_all", to: "notifications#read_all", as: :read_all_notifications
    post "notifications/:id/ack",  to: "notifications#ack",      as: :ack_notification

    post "push/subscribe",   to: "push#subscribe",   as: :push_subscribe
    post "push/unsubscribe", to: "push#unsubscribe", as: :push_unsubscribe

    get   "me", to: "profile#show", as: :profile
    patch "me", to: "profile#update"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # Root của host trần → PWA phụ huynh (dev: hiện trang launcher liệt kê 5 cổng).
  root "customer/home#show"
end
