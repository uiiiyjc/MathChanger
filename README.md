# MathChanger

把「手寫數學步驟」的照片轉成乾淨的 LaTeX。

拍一張解題過程，App 會呼叫你自己設定的視覺模型，把每一步轉成 LaTeX，
再存進手機本地的歷史記錄。

## 設計原則

- **沒有後端、沒有帳號。** 所有記錄與照片只存在這台裝置上。
- **金鑰由使用者自己填。** 不存在 App 裡，也不會隨安裝檔散佈。
- **資料會自己清掉。** 預設保留最近 15 天，上限也是 15 天。

## 環境需求

- Flutter SDK 3.4 以上（Dart 3.4+）
- iOS 或 Android 裝置／模擬器

## 執行

```sh
flutter pub get
flutter run
```

第一次開啟時，App 會請你先到**設定**頁填入你自己的 API 資訊：

| 欄位 | 說明 |
|---|---|
| API Key | 你的服務金鑰（必填） |
| Endpoint | 例如 `https://api.openai.com/v1/chat/completions` |
| Model | 例如 `gpt-4o-mini` |

金鑰透過 `flutter_secure_storage` 存進 iOS Keychain / Android Keystore，
不會以明碼落地。

### 開發用 fallback

在還沒於 App 內填過任何設定時，會退回編譯期注入的值：

```sh
flutter run \
  --dart-define=MATH_AI_API_KEY=sk-xxx \
  --dart-define=MATH_AI_ENDPOINT=https://api.openai.com/v1/chat/completions \
  --dart-define=MATH_AI_MODEL=gpt-4o-mini
```

一旦在設定頁儲存過，就以 App 內的值為準。

## 平台設定

本 repo 只包含 `lib/` 與 `pubspec.yaml`。若還沒有平台資料夾，
先用 `flutter create .` 生成，再補上以下項目。

**iOS**（`ios/Runner/Info.plist`）— `image_picker` 需要：

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相機拍攝數學題目</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>需要存取相簿以選擇數學題目照片</string>
```

**Android** — 通常不需額外設定；Android 13 以上由系統 picker 處理權限。
`minSdkVersion` 建議 23 以上（`flutter_secure_storage` 需求）。

## 資料保留

| 項目 | 行為 |
|---|---|
| 預設 / 上限 | 15 天 |
| 可調範圍 | 1～15 天 |
| 觸發時機 | 每次冷啟動，非阻塞 |
| 額外上限 | 200 筆 |
| 手動清除 | 設定頁提供「立即清除所有記錄」 |

調整保留天數時**不會默默生效**：

- **縮短** → 先告知會立刻刪掉幾筆記錄與照片，且無法復原
- **延長** → 提醒資料會累積更久、佔用更多儲存空間，記憶體與讀取負擔也會變重

## 架構

```
lib/
├── main.dart                     啟動 + 冷啟動清理
├── app_services.dart             服務容器
├── models/
│   ├── math_step.dart            MathStep / RecognitionResult
│   ├── history_entry.dart        歷史記錄
│   └── retention_policy.dart     保留策略（1～15 天）
├── services/
│   ├── math_ai_service.dart      呼叫視覺模型
│   ├── settings_service.dart     安全儲存 API 設定與保留天數
│   ├── history_repository.dart   SQLite + 圖片歸檔
│   └── cleanup_service.dart      清理與影響預估
└── screens/
    ├── capture_screen.dart       拍照／選圖
    ├── result_screen.dart        逐步 LaTeX + 複製
    ├── history_screen.dart       歷史列表
    └── settings_screen.dart      設定與保留期限
```

## Roadmap

- [x] 拍照 / 相簿 → 視覺模型 → LaTeX
- [x] 本地歷史記錄 + 自動清理
- [x] 使用者自填 API 設定
- [ ] LaTeX 渲染（`flutter_math_fork`）
- [ ] 匯出 / 分享
