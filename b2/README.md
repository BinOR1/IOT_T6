## Đặt bài toán 

- Phần cứng: Chỉ có một nút bấm nhả (push button) và 2 đèn LED hiển thị: 1 cái tích hợp sẵn trên các dev board điển hình và 1 đèn LED tích hợp bên ngoài thông qua các chân GPIO
- Yêu cầu Viết chương trình có chức năng sau:
    + bấm nút 2 lần (double click) để chuyển đổi quyền điều khiển giữa hai đèn LED
    + nhấn giữ >2s (hold) thì LED được chọn sẽ chuyển sang trạng thái nhấp nháy liên tục (blink 200ms một lần)
    + nếu nhấn single click thì LED được chọn chuyển trạng thái bật/tắt
    + Lưu ý: khử rung phím bấm 

## Thư viện sử dụng
- `BTN.h` dựa trên thư viện của thầy Nguyễn Anh Tuấn : [https://github.com/TuanPhysics/PIO-Libraries-Usage-Demo/tree/main/PushBTN_User_Lib_Demo]
- `LED.h` Cung cấp API sáng sủa để khởi tạo và điều khiển LED (đảo trạng thái - flip, và nháy - blink)

