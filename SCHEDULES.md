# Lịch của tôi

Đăng nhập bằng tài khoản nhân viên → mở menu → **Lịch của tôi**.

- Tuần hiện tại tính theo giờ Việt Nam UTC+7, không theo múi giờ thiết bị.
- Chuyển tuần bằng mũi tên, chạm khoảng ngày để chọn tuần, hoặc bấm **Tuần này**.
- Lịch hiển thị tên ca, ngày bắt đầu, giờ vào/ra, ngày kết thúc, phút nghỉ và phút làm. Ca qua đêm có nhãn ngày hôm sau.
- Chuyển trang bằng Trang trước / Trang sau; kéo xuống hoặc nút tải lại để làm mới. Khi lỗi, bấm Thử lại.
- Backend tự lọc lịch theo tài khoản đăng nhập; mobile không gửi employeeId. Chỉ role EMPLOYEE được mở màn hình này.
- Ngày bắt đầu quyết định tuần của ca: ca Chủ nhật kết thúc thứ Hai vẫn thuộc tuần Chủ nhật.
- Không có thao tác phân/hủy ca trên mobile. Quản lý thực hiện trên web.

Dùng API GET /api/v1/work-schedules?from=yyyy-MM-dd&to=yyyy-MM-dd&page=0&size=20. Backend cần migration V4. JWT dùng secure storage và client hiện có, 401 trở về đăng nhập.

Kiểm tra (không build APK):

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Test mới: `test/schedule_repository_test.dart` kiểm tra contract, UTC và lỗi; `test/schedule_widget_test.dart` kiểm tra loading/rỗng/lỗi/thử lại, ca qua đêm, đổi tuần và phân trang. Chưa kiểm tra thực tế trên emulator/thiết bị trong lần triển khai này.
