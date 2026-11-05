# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

- Giáo viên là người dùng chính trên máy tính xách tay, điều phối lớp và quản lý seating chart trong giờ học mà không làm gián đoạn tiết học.
- Cán bộ lớp và học sinh chủ yếu xem sơ đồ trên điện thoại để xác định vị trí, nhóm và thành viên.

## Product Purpose

Astatine giúp giáo viên quản lý không gian lớp học và theo dõi tình hình học sinh nhanh chóng. Seating chart phải cho phép quan sát toàn cảnh, đổi chỗ, chia nhóm và mở thông tin học sinh với số thao tác tối thiểu.

## Positioning

Seating chart kết hợp canvas vô hạn với thao tác kéo-thả, hoán đổi chỗ trực tiếp và tự động xếp nhóm dị thể dựa trên ISR (Inverse Subject Rating), thay vì buộc giáo viên xóa và nhập lại từng học sinh.

## Operating Context

Giáo viên sử dụng màn hình trong lớp học, thường cần thao tác nhanh giữa tiết học. Học sinh dùng điện thoại để xem vị trí cá nhân và các thành viên cùng nhóm. Sơ đồ có thể chứa khoảng 40–50 học sinh và cần hỗ trợ pan, zoom, recenter.

## Capabilities and Constraints

- Giữ nguyên thuật ngữ ISR (Inverse Subject Rating), được tính theo khoảng trống năng lực; không đổi tên thành Weakness Index.
- Real Score là điểm năng lực thực tế, tách biệt với XP/reward.
- XP được cộng cố định theo nhiệm vụ (Task-based XP).
- Hỗ trợ Balanced Heterogeneous Grouping: trộn học sinh dựa trên ISR.
- Hỗ trợ drag-and-drop swap giữa các bàn.
- Hỗ trợ infinite canvas pan/zoom, dot matrix background và nút Recenter luôn hiện diện.
- Khi kéo học sinh, canvas pan phải tạm khóa để tránh trượt lệch.
- Trạng thái dùng xanh lá cho thành tích cao/hoàn thành, cam-vàng cho cần hỗ trợ/chưa hoàn thành, xám cho bàn trống/vắng.
- Giữ các luồng hiện có: resize layout, đổi tên nhóm/cột, thêm/xóa học sinh, grouping, tìm kiếm và inspector hồ sơ.

## Product Principles

- Tốc độ thao tác quan trọng hơn trang trí.
- Không gian lớp học phải đọc được trong một cái nhìn.
- Dữ liệu năng lực, động lực và trạng thái phải được phân biệt rõ.
- Mọi thao tác phá hủy hoặc thay đổi vị trí phải có feedback trực quan.
- Canvas phải usable bằng chuột, trackpad và màn hình nhỏ.

## Accessibility & Inclusion

- Contrast tối thiểu WCAG 4.5:1 cho tên, điểm số và badge trạng thái.
- Trạng thái không chỉ được biểu diễn bằng màu; phải có nhãn/icon tương ứng.
- Hit target đủ lớn cho thao tác cảm ứng trên điện thoại.
- Zoom nhỏ vẫn giữ thông tin cốt lõi có thể đọc được.
