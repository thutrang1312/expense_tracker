# BÁO CÁO KỸ THUẬT MINI-PROJECT

**Học phần:** Phát triển ứng dụng di động đa nền tảng (VKU)  
**Tên đề tài:** Expense Tracker  
**Nhóm / Sinh viên:** [Tên nhóm / Họ tên sinh viên]  
**Ngày nộp:** [DD/MM/YYYY]

---

## 1. THÔNG TIN CHUNG VÀ SẢN PHẨM

* **Thành viên:**
  1. [Họ và tên] — MSSV: [22ITxxx] — Vai trò: [Nhóm trưởng / Phát triển giao diện] — Đóng góp: [%]
  2. [Họ và tên] — MSSV: [22ITyyy] — Vai trò: [Phát triển xử lý dữ liệu / Kiểm thử] — Đóng góp: [%]
* **Bản demo / APK:** [Điền liên kết]
* **Mã nguồn GitHub:** [Điền liên kết]
* **Video demo (nếu có):** [Điền liên kết]

---

## 2. TỔNG QUAN DỰ ÁN

Expense Tracker là ứng dụng quản lý chi tiêu cá nhân được xây dựng bằng Flutter. Ứng dụng cho phép người dùng đăng nhập, ghi nhận giao dịch, phân loại khoản chi, xem tổng quan chi tiêu và theo dõi lịch sử giao dịch.

Người dùng có thể chụp ảnh bằng camera hoặc chọn ảnh giao dịch từ thư viện. Trên Android và iOS, ứng dụng sử dụng Google ML Kit Text Recognition để nhận diện văn bản ngay trên thiết bị. Bộ xử lý tìm các thông tin như số tiền, ngày giao dịch và nội dung liên quan để điền sẵn vào biểu mẫu. Người dùng có thể kiểm tra, chỉnh sửa thông tin trước khi lưu. Đây là nhận diện văn bản từ ảnh (OCR), không phải tính năng tự động nhận diện đầy đủ mọi loại hóa đơn; kết quả còn phụ thuộc chất lượng ảnh và định dạng nội dung.

Ứng dụng sử dụng Supabase để xác thực tài khoản và lưu giao dịch trực tuyến. Khi xảy ra lỗi kết nối mạng, các giao dịch có thể được lưu cục bộ để người dùng tiếp tục thao tác và chờ đồng bộ.

---

## 3. CÁC TÍNH NĂNG CHÍNH

| # | Tính năng | Mô tả |
|:---:|---|---|
| 1 | Quản lý giao dịch | Tạo, chỉnh sửa, xóa và xem danh sách các khoản chi; mỗi giao dịch có số tiền, ngày, danh mục và thông tin mô tả. |
| 2 | Nhận diện chữ từ ảnh (OCR) | Chụp hoặc chọn ảnh giao dịch. Trên Android/iOS, ML Kit chạy nhận diện văn bản trên thiết bị và hỗ trợ trích xuất số tiền, ngày, nội dung. Người dùng xác nhận hoặc chỉnh sửa trước khi lưu. |
| 3 | Dashboard và biểu đồ | Hiển thị tổng chi tiêu, phân bổ theo danh mục và biểu đồ chi tiêu 7 ngày gần đây. |
| 4 | Lưu cục bộ khi mất mạng | Khi thao tác với giao dịch gặp lỗi mạng, ứng dụng lưu dữ liệu và thao tác chờ xử lý vào bộ nhớ cục bộ. |
| 5 | Đồng bộ với Supabase | Các thao tác đang chờ được gửi lên Supabase trong lần ứng dụng tải dữ liệu tiếp theo khi kết nối hoạt động. Đây là đồng bộ theo lần tải dữ liệu, không phải dịch vụ đồng bộ nền liên tục. |

**Giới hạn nền tảng:** Phần OCR dùng ML Kit và chỉ được hỗ trợ trên Android/iOS trong luồng hiện tại. Khi chạy trên web, ứng dụng thông báo tính năng nhận diện ảnh chưa được hỗ trợ.

---

## 4. KIẾN TRÚC VÀ CẤU TRÚC DỰ ÁN

Dự án sử dụng Flutter/Dart cho giao diện và xử lý ứng dụng. Các phần chính trong thư mục `lib` gồm:

- `screens`: các màn hình đăng nhập, trang tổng quan, quét/chọn ảnh và xem lại giao dịch.
- `services`: xử lý truy cập Supabase, lưu trữ cục bộ, đồng bộ giao dịch và nhận diện nội dung ảnh.
- `models`: mô hình dữ liệu giao dịch và chuyển đổi dữ liệu giữa ứng dụng với cơ sở dữ liệu.
- `widgets/charts`: các thành phần vẽ biểu đồ cột và biểu đồ phân bổ danh mục.

Luồng lưu giao dịch bắt đầu từ biểu mẫu xác nhận. Khi có mạng, ứng dụng gửi giao dịch đến bảng `expenses` trên Supabase gắn với tài khoản hiện tại. Nếu phát sinh lỗi mạng, `DatabaseHelper` chuyển thao tác sang `ExpenseLocalStore`. Ở lần tải danh sách giao dịch tiếp theo, ứng dụng thử gửi các thao tác chờ lên Supabase rồi tải dữ liệu mới nhất. Nếu mạng vẫn không hoạt động, danh sách giao dịch được đọc từ bộ nhớ cục bộ.

Ảnh giao dịch được sao chép vào thư mục tài liệu của ứng dụng trên thiết bị để giữ lại ảnh đã chọn. OCR được thực hiện cục bộ bởi ML Kit; văn bản/ảnh không được gửi lên dịch vụ OCR từ luồng xử lý này.

---

## 5. CÁCH SỬ DỤNG

1. Người dùng đăng nhập vào ứng dụng.
2. Tại trang tổng quan, người dùng xem tổng chi tiêu, biểu đồ 7 ngày và danh sách giao dịch.
3. Để tạo giao dịch, người dùng chọn thao tác chụp ảnh hoặc chọn ảnh giao dịch.
4. Trên Android/iOS, ứng dụng nhận diện văn bản trên ảnh và điền thông tin tìm được vào màn hình xem lại.
5. Người dùng kiểm tra, chỉnh sửa số tiền, ngày, danh mục hoặc thông tin giao dịch, rồi lưu.
6. Nếu không có mạng, ứng dụng lưu giao dịch cục bộ. Khi kết nối hoạt động trở lại, thao tác chờ được đồng bộ trong lần tải dữ liệu tiếp theo.

---

## 6. THÁCH THỨC KỸ THUẬT VÀ GIẢI PHÁP

### 6.1. Nhận diện ảnh trên nhiều nền tảng

ML Kit Text Recognition được tích hợp cho Android và iOS nhưng không dùng được trong luồng web hiện tại. Ngoài ra, ảnh cục bộ trên Flutter Web không thể hiển thị bằng `Image.file`. Ứng dụng giới hạn luồng OCR cho nền tảng di động và kiểm tra nền tảng trước khi xử lý ảnh, tránh gọi tính năng không được hỗ trợ trên web.

### 6.2. Duy trì dữ liệu khi mất mạng

Nếu chỉ lưu trực tiếp lên server, thao tác có thể thất bại khi mất kết nối. Ứng dụng giải quyết bằng cách lưu giao dịch và thao tác chờ vào `ExpenseLocalStore`, sau đó thử đồng bộ khi tải danh sách giao dịch trong lúc mạng đã hoạt động. Cách này giúp giữ lại dữ liệu trong tình huống offline; việc đồng bộ không chạy như một tác vụ nền liên tục.

### 6.3. Trích xuất thông tin từ ảnh không đồng nhất

Ảnh giao dịch có thể khác nhau về bố cục, độ rõ và cách viết số tiền. Bộ phân tích ưu tiên các nhãn thường gặp như “Tổng cộng”, “Thanh toán”, “Tổng” và “Số tiền”. Kết quả nhận diện được đưa cho người dùng kiểm tra trước khi lưu thay vì xem là dữ liệu luôn chính xác.

---

## 7. MINH CHỨNG CHẠY ỨNG DỤNG

Chèn ảnh chụp thực tế từ ứng dụng vào các vị trí dưới đây:

1. **Trang tổng quan:** tổng chi tiêu, phân bổ danh mục và biểu đồ 7 ngày.
2. **Màn hình chụp/chọn ảnh:** thao tác đưa ảnh giao dịch vào ứng dụng.
3. **Màn hình xem lại:** thông tin nhận diện được để người dùng kiểm tra, chỉnh sửa.
4. **Danh sách giao dịch hoặc trạng thái offline:** minh họa dữ liệu đã lưu và trạng thái đồng bộ nếu có.

*Chỉ ghi các nền tảng và trường hợp kiểm thử đã thực sự chạy; có thể ghi thiết bị, phiên bản hệ điều hành và kết quả kiểm thử dưới từng ảnh.*

---

## 8. KẾT LUẬN

Expense Tracker cung cấp các chức năng cốt lõi để ghi nhận và theo dõi chi tiêu cá nhân: quản lý giao dịch, tổng hợp dữ liệu trên dashboard, nhận diện văn bản từ ảnh giao dịch trên Android/iOS và lưu cục bộ khi gặp lỗi mạng. Supabase đảm nhiệm xác thực và lưu dữ liệu trực tuyến; các thao tác lưu cục bộ được đưa lên server trong lần ứng dụng tải dữ liệu tiếp theo khi kết nối hoạt động.

Trong tương lai, dự án có thể cải thiện độ chính xác của việc trích xuất dữ liệu, bổ sung kiểm thử đồng bộ trong các tình huống mất mạng và xem xét hỗ trợ nhận diện ảnh trên web.
