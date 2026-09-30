# MathChanger

> 透過 AI 將圖片中的數學解題過程轉換為 LaTeX 格式。
> Turn math steps found in an image into clean LaTeX, using a vision-capable LLM.

**狀態：早期骨架（scaffold）** — UI 與資料流已接通，可直接跑；正式後端與金鑰管理尚未處理。

## 功能

- 📷 拍照或從相簿選圖
- 🤖 呼叫支援視覺的 LLM，把解題步驟逐行轉成 LaTeX
- 📋 一鍵複製單一步驟或全部結果
- 🔐 API 金鑰透過 `--dart-define` 注入，不進版控

## 專案結構

```
lib/
├── main.dart                       應用入口與主題
├── models/math_step.dart           資料模型：MathStep / RecognitionResult
├── services/math_ai_service.dart   視覺模型呼叫與 JSON 解析
└── screens/
    ├── capture_screen.dart         首頁：選圖 + 觸發轉換
    └── result_screen.dart          結果頁：逐步 LaTeX + 複製
```

## 開始使用

```sh
flutter pub get

flutter run \
  --dart-define=MATH_AI_API_KEY=<你的金鑰> \
  --dart-define=MATH_AI_MODEL=gpt-4o-mini
```

可用參數：

| 參數 | 預設值 | 說明 |
|------|--------|------|
| `MATH_AI_API_KEY` | 必填 | 模型供應商的 API Key |
| `MATH_AI_ENDPOINT` | `https://api.openai.com/v1/chat/completions` | Chat Completions 端點 |
| `MATH_AI_MODEL` | `gpt-4o-mini` | 使用的視覺模型 |

> ⚠️ 不要讓金鑰寫進 `lib/` 或任何會被提交的檔案。

## Roadmap

- [ ] App 內直接渲染 LaTeX（目前顯示原始碼）
- [ ] 歷史紀錄與離線快取
- [ ] 匯出 `.tex` / 圖片
- [ ] 錯誤處理與重試策略強化
- [ ] 串接自架後端，避免前端暴露金鑰

## 授權

本專案依 [LICENSE](LICENSE) 條款釋出。
