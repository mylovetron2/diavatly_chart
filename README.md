# DVL Chart Flutter App

Ứng dụng cho phép chọn file dữ liệu dạng text, trích xuất các trường TIME, LPM, RPM, LITER và vẽ đồ thị với trục y là TIME (từ trên xuống), trục x là các giá trị LPM, RPM, LITER.

## Cài đặt

1. Cài đặt Flutter SDK: https://docs.flutter.dev/get-started/install
2. Cài đặt dependencies:
   ```
   flutter pub get
   ```
3. Chạy ứng dụng:
   ```
   flutter run
   ```

## Chức năng
- Chọn file đầu vào định dạng text
- Parse dữ liệu TIME, LPM, RPM, LITER
- Vẽ đồ thị dạng BarChart với trục y là TIME, trục x là LPM, RPM, LITER

## Ghi chú
- File đầu vào cần đúng định dạng mẫu:
  ```
  TIME       FLOW      SPD     WATER
  DD:HH:MM:SS        LPM      RPM     LITER
  0:00:00:03     419.5   612.5      21.0
  ...
  ```
- Có thể cần chỉnh lại tỉ lệ hiển thị trên đồ thị cho phù hợp dữ liệu thực tế.
