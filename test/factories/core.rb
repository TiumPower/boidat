FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Trung tâm bơi #{n}" }
    sequence(:subdomain) { |n| "tt#{n}" }
    status { "active" }
    plan { "pro" }
    paid_until { 1.year.from_now }
  end

  factory :admin_user do
    sequence(:email) { |n| "ops#{n}@boidat.vn" }
    name { "Operator" }
    password { "boidat1234" }
    role { "superadmin" }
  end

  factory :user do
    sequence(:email) { |n| "staff#{n}@boidat.vn" }
    name { "Nhân sự" }
    password { "boidat1234" }
    locale { "vi" }
  end

  factory :pool do
    workspace
    sequence(:name) { |n| "Hồ #{n}" }
    status { "active" }
  end

  factory :teacher_level do
    workspace
    sequence(:name) { |n| "Level #{n}" }
    max_students_per_slot { 3 }
    pay_rate_per_credit { 90_000 }
  end

  factory :teacher do
    workspace
    user
    teacher_level
    kind { "staff" }
    status { "active" }
  end

  factory :household do
    workspace
    sequence(:name) { |n| "Gia đình #{n}" }
    kind { "family" }
  end

  factory :guardian do
    workspace
    household
    sequence(:name) { |n| "Phụ huynh #{n}" }
    sequence(:phone) { |n| "09000000#{format('%02d', n % 100)}" }
    role { "owner" }
  end

  factory :student do
    workspace
    household
    pool
    sequence(:name) { |n| "Học viên #{n}" }
    birthdate { 8.years.ago.to_date }
    kind { "center" }
    status { "active" }
  end
end
