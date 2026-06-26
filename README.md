# Battle of Talingchan 5G (Fanmade)

แฟนเกมการ์ดที่อิงกติกาจริงของ **Battle of Talingchan** (https://bangbon.app/cards)

เอนจิน: **LÖVE 11.5** - ใช้ฟอนต์ **Kanit** (SIL Open Font License) จาก Google Fonts
เพื่อรองรับภาษาไทยเต็มรูปแบบ (ฟอนต์ Inter/NotoSansJP ไม่รองรับไทย)

## วิธีเล่น

### Windows (พร้อมเล่นทันที)
เปิด `BattleOfTalingchan5G.exe` ในโฟลเดอร์ `BattleOfTalingchan5G-win64/` ได้เลย
(ต้องมี DLL ทั้งหมดอยู่ในโฟลเดอร์เดียวกัน)

### เครื่องอื่น (Mac/Linux) หรือต้องการแก้โค้ด
ต้องติดตั้ง [LÖVE 11.5](https://love2d.org/) แล้ว:
- ลาก `game.love` ไปวางบนตัว LÖVE หรือรัน `love game.love`
- หรือ clone โค้ดต้นฉบับ (`source/`) แล้วรัน `love source/`

## โหมดเกม

1. **Local Hotseat** - เล่น 2 คนสลับเทิร์นบนเครื่องเดียว มีหน้าจอ "ส่งจอให้อีกฝ่าย"
   ป้องกันการเห็นมือคู่ต่อสู้
2. **เล่นกับ AI บอท** - บอทใช้ตรรกะแบบ heuristic (สรุปการ์ด, โจมตีเมื่อได้เปรียบ)
3. **สร้างห้อง / เข้าร่วมห้อง 5G** - เล่นออนไลน์ผ่าน LAN หรือ Internet (ต้อง forward
   port `22122` เองถ้าเล่นข้ามเครือข่าย เพราะไม่มี relay server กลาง) ใช้ enet
   (bundled กับ LÖVE) host เป็นผู้ตัดสิน (authoritative), client ส่งแค่คำสั่งแล้วรอ
   state กลับมา - กันปัญหา desync ได้ 100%

ทุกโหมดเริ่มด้วยการ **เป่ายิ้งฉุบ (ค้อน/กรรไกร/กระดาษ)** เพื่อตัดสินว่าใครได้
เลือกไปก่อนหรือไปทีหลัง ถ้าเสมอจะเป่าใหม่ไปเรื่อยๆ

## กติกาที่ implement ไว้ (อิงกติกาจริงของเกม)

- โซน: Deck, Hand, Graveyard (นรก), Avatar Zone (4 ช่อง), Magic Zone, Life Card
  Zone (5 ใบ), Land Magic Zone (กลางสนาม ใช้ร่วมกัน), Construct Zone
- เฟส: Draw → Main → Attack → End (เทิร์นแรกของเกมโจมตีไม่ได้)
- อัญเชิญ Avatar ด้วยการทิ้งการ์ดในมือที่มีค่า **เจม (Gem)** รวมกัน ≥ ค่าคอร์ส
  (v1: ระบบเลือกค่าใช้จ่ายให้อัตโนมัติแบบ "การ์ดเจมสูงสุดก่อน" เพื่อความง่าย —
  เลือกเองแบบละเอียดเป็นแผนต่อยอด v2)
- การต่อสู้: พลังมากกว่าทำลายฝ่ายตรงข้าม, เท่ากันทำลายทั้งคู่, ต้องเคลียร์ Avatar
  ก่อนตี Life Card (ยกเว้นมีความสามารถ "เตะไข่"/Direct Attack)
- Magic 4 แบบ: Land (ส่งผลทั้งสองฝ่าย), Weapon (ติดอาวุธให้ Avatar), Normal
  (ใช้แล้วลงนรก), Counter (ใช้ตอบโต้ตอนคู่ต่อสู้อัญเชิญ Avatar เท่านั้น —
  ระบบเปิด "หน้าต่างตอบโต้" ให้อีกฝ่ายเลือกก่อนเกมจะไปต่อ)
- ความสามารถพิเศษ: หมาหมู่ (Mob, พลังเพิ่มตามจำนวนเผ่าเดียวกัน), จุติ (Ascension,
  ดึงการ์ดจากนรกกลับกองจั่ว), ธรณีสูบ (Earth Absorption, Counter ทำลาย Avatar ที่
  เพิ่งอัญเชิญ), บัฟเผ่า, กวนมือคู่ต่อสู้
- แพ้เมื่อ: Life Card หมด 5 ใบ (เข้าสถานะ [สาหัส]) แล้วโดนตีซ้ำ, หรือกองจั่วหมด
  (deck-out)

## โครงสร้างโค้ด

```
main.lua, conf.lua          จุดเริ่มต้นเกม + ตั้งค่าหน้าต่าง
src/cards.lua                ฐานข้อมูลการ์ดต้นฉบับทั้งหมด
src/decks.lua                เด็คสำเร็จรูป 2 เด็ค (แก๊งเสา 5G / เทวดาขายตรง)
src/engine/match.lua          เอนจินกติกาหลัก (ตัวตัดสินเกมที่แท้จริง)
src/engine/ai.lua             บอท AI
src/engine/costcalc.lua       คำนวณค่าใช้จ่ายแบบ pure function (ใช้ฝั่ง client ด้วย)
src/net/                      ระบบเน็ตเวิร์ก (enet) + protocol
src/ui/                       การ์ด, ปุ่ม, กระดานเกม, log
src/scenes/                   เมนู, ห้อง, เป่ายิ้งฉุบ, หน้าจอเกมหลัก
tests/                        ชุดทดสอบอัตโนมัติ (รันด้วย Lua 5.5 ปกติ ไม่ต้องใช้ LÖVE)
```

### รัน automated tests (Lua 5.5 ธรรมดา ไม่ใช่ LÖVE)
```
lua5.5 tests/test_engine.lua        # กติกาแกนหลัก
lua5.5 tests/test_engine2.lua       # weapon/land/counter/win-condition
lua5.5 tests/test_ai.lua            # AI vs AI จำลอง
lua5.5 tests/test_hotseat_smoke.lua # UI hotseat
lua5.5 tests/test_ui_smoke.lua      # UI เต็มรูปแบบ (จำลองคลิกเมาส์จริง)
lua5.5 tests/test_network_smoke.lua # host/client protocol (mock network)
```
ทุกไฟล์ผ่านหมดแล้วในการพัฒนา - `test_ui_smoke.lua` เคยจับบั๊กจริงได้ 1 ตัว
(AI ไม่เริ่มเล่นถ้าเป่ายิ้งฉุบแล้วบอทได้ไปก่อน) ก่อนส่งมอบ

## ข้อจำกัดที่รู้อยู่แล้ว (v1 → ต่อยอด v2 ได้)
- เลือกการ์ดมาจ่ายค่าคอร์สอัตโนมัติ (ไม่ให้เลือกเองทีละใบ)
- "จุติ" ดึงการ์ดล่าสุดในนรกอัตโนมัติ (ไม่มี UI เลือกใบที่ต้องการ)
- ไม่มี matchmaking server กลาง ต้องแชร์ IP กันเอง (เล่นข้ามเน็ตต้อง forward port)
- ยังไม่มีอนิเมชัน/เอฟเฟกต์เสียง
- การ์ดมี 30 ใบต้นฉบับ (พอสร้าง 2 เด็ค 50 ใบ) - เพิ่มได้ง่ายใน `src/cards.lua`

## เครดิต
- กติกาเกม: อิงจาก Battle of Talingchan โดย bangbon.app (ไม่ใช่ผู้สร้าง ไม่เกี่ยวข้อง
  กับทีมพัฒนาเกมต้นฉบับ)
- ฟอนต์: Kanit by Cadson Demak (SIL OFL 1.1) — ดู `assets/fonts/OFL.txt`
- เอนจิน: LÖVE 11.5 (https://love2d.org/)
