# `SwimClass.teaching` lọc bằng MAX(lessons.date) theo từng lớp, và nó nằm trên
# đường nóng: bảng lịch, bộ xếp lịch, cổng phụ huynh, chỉ số dashboard — mười
# một chỗ gọi. Chỉ mục hiện có là (swim_class_id, session_index), không giúp gì
# cho MAX(date).
#
# Ở khối lượng hiện tại (324 buổi) Postgres vẫn quét bảng và chỉ mục này không
# đổi gì đo được. Nó dành cho lúc ba hồ chạy vài năm.
class IndexLessonsOnClassAndDate < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :lessons, [:swim_class_id, :date], algorithm: :concurrently,
              if_not_exists: true
  end
end
