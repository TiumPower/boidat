namespace :storage do
  desc "Kiểm tra kết nối tới kho lưu trữ đang cấu hình (ghi thử một tệp rồi xoá)"
  task check: :environment do
    service = ActiveStorage::Blob.service
    puts "dịch vụ: #{Rails.application.config.active_storage.service} (#{service.class.name.demodulize})"

    if service.is_a?(ActiveStorage::Service::DiskService)
      puts "→ đang dùng đĩa của máy chủ. Đặt SPACES_* trong .env để chuyển sang Spaces."
      next
    end

    key = "healthcheck/#{SecureRandom.hex(8)}"
    body = "boidat storage check #{Time.current.iso8601}"
    service.upload(key, StringIO.new(body), checksum: OpenSSL::Digest::MD5.base64digest(body))
    ok = service.download(key) == body
    service.delete(key)
    puts ok ? "→ ghi, đọc, xoá: OK" : "→ LỖI: đọc lại không khớp nội dung vừa ghi"
    abort "kho lưu trữ không dùng được" unless ok
  rescue StandardError => e
    abort "→ LỖI #{e.class}: #{e.message}"
  end

  desc "Chuyển mọi tệp đang nằm trên đĩa sang kho hiện tại (không xoá bản gốc)"
  task migrate: :environment do
    target = ActiveStorage::Blob.service
    target_name = Rails.application.config.active_storage.service.to_s
    if target.is_a?(ActiveStorage::Service::DiskService)
      abort "Kho đích vẫn là đĩa — đặt SPACES_* trước đã, nếu không đây là việc vô nghĩa."
    end

    # `config.active_storage.service_configurations` rỗng lúc chạy; registry mới
    # là nơi các kho đã dựng sẵn nằm.
    disk = ActiveStorage::Blob.services.fetch(:local)
    pending = ActiveStorage::Blob.where.not(service_name: target_name)
    puts "cần chuyển: #{pending.count} tệp (#{ActiveSupport::NumberHelper.number_to_human_size(pending.sum(:byte_size))})"

    moved = skipped = failed = 0
    pending.find_each do |blob|
      if target.exist?(blob.key)
        blob.update_column(:service_name, target_name)
        skipped += 1
        next
      end
      unless disk.exist?(blob.key)
        warn "  THIẾU trên đĩa: #{blob.key} (#{blob.filename})"
        failed += 1
        next
      end

      disk.open(blob.key, checksum: blob.checksum) do |file|
        target.upload(blob.key, file, checksum: blob.checksum,
                      content_type: blob.content_type, filename: blob.filename)
      end
      # Chỉ đổi service_name SAU khi đã đọc lại được từ kho mới. Đổi trước là
      # tự tay trỏ ứng dụng vào một tệp có thể chưa lên tới nơi.
      unless target.exist?(blob.key)
        warn "  GHI HỤT: #{blob.key}"
        failed += 1
        next
      end
      blob.update_column(:service_name, target_name)
      moved += 1
      print "."
    end

    puts
    puts "chuyển #{moved} · đã có sẵn #{skipped} · hỏng #{failed}"
    puts "Bản gốc trên đĩa CÒN NGUYÊN. Chỉ xoá sau khi đã chạy storage:verify và"
    puts "sao lưu ít nhất một đêm với kho mới."
    abort "còn #{failed} tệp chưa chuyển được" if failed.positive?
  end

  desc "Đối chiếu: mọi blob đều đọc được và đúng checksum"
  task verify: :environment do
    bad = []
    ActiveStorage::Blob.find_each do |blob|
      service = ActiveStorage::Blob.services.fetch(blob.service_name.to_sym)
      unless service.exist?(blob.key)
        bad << [blob, "không tồn tại trong kho #{blob.service_name}"]
        next
      end
      actual = OpenSSL::Digest::MD5.base64digest(service.download(blob.key))
      bad << [blob, "checksum lệch"] if actual != blob.checksum
    end

    total = ActiveStorage::Blob.count
    if bad.empty?
      puts "#{total}/#{total} tệp đọc được và đúng checksum."
    else
      bad.each { |b, why| puts "  #{b.key} (#{b.filename}): #{why}" }
      abort "#{bad.size}/#{total} tệp có vấn đề"
    end
  end
end
