# 단톡방 iOS 앱 껍데기 (com.weaveapp.dantok)

- 화면은 https://dantok.kr 에서 그대로 불러옵니다. 화면 수정은 dantok 저장소(웹)만 고치면 됩니다.
- 단골창구(dangol-ios)와 같은 방식: 폴더 없이 파일만 두고, Codemagic 이 빌드 때 `npx cap add ios` 로 아이폰 폴더를 만든 뒤 ios_setup.py 가 설정을 끼워 넣습니다.
- 앱이 하는 일은 두 가지뿐: ① 알림(Firebase → dt.js pushSync → dt_push) ② 애플 결제(→ aliascall-google-verify → dt_grant_paid)
- 권한 안내: 카메라 · 마이크(음성 메시지) · 사진 보관함

## 애플 결제 상품 (모두 「비갱신 구독」 · 1년)
| 애플 상품 ID | 이름 | 값 |
|---|---|---|
| dantok_room_1y_nr | 방 이용 1년 연장 | 9,900원 |
| dantok_room_10g_nr | 방 저장 공간 +10GB · 1년 | 7,900원 |
| dantok_gal_5g_nr | 내 갤러리 5GB · 1년 | 4,900원 |
| dantok_gal_15g_nr | 내 갤러리 15GB · 1년 | 9,900원 |

화면은 `dantok_room_1y` 처럼 부르고, 앱이 끝에 `_nr` 를 붙여 애플에서 찾습니다.

## 저장소에 직접 넣어야 할 것 (채팅에 붙이지 마세요)
- `GoogleService-Info.plist` — Firebase 에일리어스콜 프로젝트 → iOS 앱 com.weaveapp.dantok 에서 받은 파일
